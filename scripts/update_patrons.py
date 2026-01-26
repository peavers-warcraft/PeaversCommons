#!/usr/bin/env python3
"""
Fetch patrons from Patreon API and update PatronsInit.lua

This script fetches all campaign members from the Patreon API and generates
a Lua file with the patron list, distinguishing between paying patrons and
free followers.

Required environment variables:
    PATREON_ACCESS_TOKEN: Creator Access Token from Patreon Developer Portal
    PATREON_CAMPAIGN_ID: Your campaign ID (optional, will auto-detect if not set)
"""

import os
import sys
import json
import hashlib
from urllib.request import Request, urlopen
from urllib.error import HTTPError, URLError
from pathlib import Path


PATREON_API_BASE = "https://www.patreon.com/api/oauth2/v2"
LUA_OUTPUT_PATH = Path(__file__).parent.parent / "src" / "Core" / "PatronsInit.lua"


def fetch_json(url: str, access_token: str) -> dict:
    """Fetch JSON from Patreon API with authentication."""
    request = Request(url)
    request.add_header("Authorization", f"Bearer {access_token}")
    request.add_header("Content-Type", "application/json")

    try:
        with urlopen(request, timeout=30) as response:
            content = response.read().decode("utf-8")
            return json.loads(content)
    except HTTPError as e:
        print(f"HTTP Error {e.code}: {e.reason}", file=sys.stderr)
        print(f"URL: {url}", file=sys.stderr)
        if e.code == 401:
            print("Authentication failed. Check your PATREON_ACCESS_TOKEN.", file=sys.stderr)
        sys.exit(1)
    except URLError as e:
        print(f"URL Error: {e.reason}", file=sys.stderr)
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"JSON decode error: {e}", file=sys.stderr)
        print(f"URL: {url}", file=sys.stderr)
        sys.exit(1)
    except TimeoutError:
        print(f"Request timed out for URL: {url}", file=sys.stderr)
        sys.exit(1)


def get_campaign_id(access_token: str) -> str:
    """Get the first campaign ID for the authenticated user."""
    url = f"{PATREON_API_BASE}/campaigns"
    data = fetch_json(url, access_token)

    if not data.get("data"):
        print("No campaigns found for this account.")
        sys.exit(1)

    campaign_id = data["data"][0]["id"]
    print(f"Found campaign ID: {campaign_id}")
    return campaign_id


def fetch_all_members(access_token: str, campaign_id: str) -> list[dict]:
    """Fetch all campaign members with pagination."""
    members = []
    max_pages = 100  # Safety limit to prevent infinite loops

    # Build the URL with fields we need
    # patron_status: active_patron, declined_patron, former_patron, null (free follower)
    # currently_entitled_amount_cents: > 0 means paying patron
    fields = "full_name,patron_status,currently_entitled_amount_cents,email"
    url = f"{PATREON_API_BASE}/campaigns/{campaign_id}/members?fields[member]={fields}&page[count]=500"

    page_count = 0
    previous_url = None

    while url and page_count < max_pages:
        # Prevent infinite loop if API returns same URL
        if url == previous_url:
            print(f"Warning: Pagination returned same URL, stopping", file=sys.stderr)
            break

        page_count += 1
        print(f"Fetching members page {page_count}...")
        data = fetch_json(url, access_token)

        for member in data.get("data", []):
            attrs = member.get("attributes", {})
            members.append({
                "name": attrs.get("full_name", "Anonymous"),
                "status": attrs.get("patron_status"),
                "amount_cents": attrs.get("currently_entitled_amount_cents", 0) or 0,
            })

        # Handle pagination
        previous_url = url
        url = data.get("links", {}).get("next")

    if page_count >= max_pages:
        print(f"Warning: Reached maximum page limit ({max_pages})", file=sys.stderr)

    return members


def categorize_members(members: list[dict]) -> tuple[list[str], list[str]]:
    """
    Categorize members into paying patrons and free followers.

    Returns:
        Tuple of (paying_patrons, free_followers) - each a sorted list of names
    """
    paying_patrons = []
    free_followers = []

    for member in members:
        name = member["name"]
        if not name or name == "Anonymous":
            continue

        # A paying patron has active status AND is contributing money
        is_paying = (
            member["status"] == "active_patron" and
            member["amount_cents"] > 0
        )

        if is_paying:
            paying_patrons.append(name)
        else:
            # Include followers and free members
            free_followers.append(name)

    # Sort alphabetically
    paying_patrons.sort(key=str.lower)
    free_followers.sort(key=str.lower)

    return paying_patrons, free_followers


def generate_lua(paying_patrons: list[str], free_followers: list[str]) -> str:
    """Generate the PatronsInit.lua file content."""

    def lua_escape(s: str) -> str:
        """Escape a string for Lua double-quoted strings."""
        return (s
            .replace("\\", "\\\\")
            .replace('"', '\\"')
            .replace("\n", "\\n")
            .replace("\r", "\\r")
            .replace("\t", "\\t")
            .replace("\0", "")  # Remove null bytes
        )

    def format_patron_list(names: list[str], tier: str) -> str:
        """Format a list of names as Lua table entries."""
        if not names:
            return ""
        entries = []
        for name in names:
            escaped = lua_escape(name)
            entries.append(f'        {{ name = "{escaped}", tier = "{tier}" }},')
        return "\n".join(entries)

    paying_lua = format_patron_list(paying_patrons, "gold")
    followers_lua = format_patron_list(free_followers, "silver")

    # Combine both lists
    all_entries = []
    if paying_lua:
        all_entries.append(paying_lua)
    if followers_lua:
        all_entries.append(followers_lua)

    combined = "\n".join(all_entries) if all_entries else "        -- No patrons yet"

    return f'''-- AUTO-GENERATED FILE - DO NOT EDIT MANUALLY
-- This file is automatically updated by GitHub Actions from Patreon data
-- Last updated: See git commit timestamp

local PeaversCommons = _G.PeaversCommons
local Patrons = PeaversCommons.Patrons

local function InitializePatrons()
    if not Patrons or not Patrons.AddPatrons then
        return false
    end

    -- Clear existing patrons to prevent duplicates on reload
    if Patrons.Clear then
        Patrons:Clear()
    end

    Patrons:AddPatrons({{
{combined}
    }})

    return true
end

InitializePatrons()

return InitializePatrons
'''


def compute_hash(content: str) -> str:
    """Compute a hash of the content for change detection."""
    return hashlib.sha256(content.encode("utf-8")).hexdigest()[:16]


def main():
    # Get credentials from environment
    access_token = os.environ.get("PATREON_ACCESS_TOKEN")
    if not access_token:
        print("Error: PATREON_ACCESS_TOKEN environment variable not set")
        sys.exit(1)

    campaign_id = os.environ.get("PATREON_CAMPAIGN_ID")

    # Get campaign ID if not provided
    if not campaign_id:
        campaign_id = get_campaign_id(access_token)

    print(f"Fetching members for campaign {campaign_id}...")

    # Fetch all members
    members = fetch_all_members(access_token, campaign_id)
    print(f"Found {len(members)} total members")

    # Categorize into paying and free
    paying_patrons, free_followers = categorize_members(members)
    print(f"Paying patrons: {len(paying_patrons)}")
    print(f"Free followers: {len(free_followers)}")

    # Generate Lua content
    lua_content = generate_lua(paying_patrons, free_followers)

    # Check if content has changed
    if LUA_OUTPUT_PATH.exists():
        existing_content = LUA_OUTPUT_PATH.read_text()
        # Compare excluding the auto-generated comment lines (which might have timestamps)
        existing_lines = [l for l in existing_content.split("\n") if not l.startswith("--")]
        new_lines = [l for l in lua_content.split("\n") if not l.startswith("--")]

        if existing_lines == new_lines:
            print("No changes detected in patron list.")
            # Write to GitHub output if available
            github_output = os.environ.get("GITHUB_OUTPUT")
            if github_output:
                with open(github_output, "a") as f:
                    f.write("changed=false\n")
            return

    # Ensure parent directory exists
    LUA_OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)

    # Write the new content
    LUA_OUTPUT_PATH.write_text(lua_content)
    print(f"Updated {LUA_OUTPUT_PATH}")

    # Write to GitHub output if available
    github_output = os.environ.get("GITHUB_OUTPUT")
    if github_output:
        with open(github_output, "a") as f:
            f.write("changed=true\n")
            f.write(f"paying_count={len(paying_patrons)}\n")
            f.write(f"follower_count={len(free_followers)}\n")

    # Print the patron names for the commit message
    if paying_patrons:
        print("\nPaying patrons:")
        for name in paying_patrons:
            print(f"  - {name}")

    if free_followers:
        print("\nFree followers:")
        for name in free_followers:
            print(f"  - {name}")


if __name__ == "__main__":
    main()
