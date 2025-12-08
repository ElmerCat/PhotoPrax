# Contributing to PhotoPrax

This project prefers editing existing files over adding new ones with similar names. Duplicate files or types can cause build errors (e.g., "Multiple commands produce … .stringsdata"). Please follow the checklist below when making changes.

## Policy: Edit, Don’t Duplicate
- Never create a new file with a name that already exists in the project.
- If you need to change an existing type (e.g., `ContentColumnView`), update the canonical file instead of creating a similarly named file.
- If you cannot locate the file, ask for the exact path or request the current file contents before proceeding.

## Checklist Before Committing
1) Confirm the file path and target membership
- Verify the exact path of the file to be changed (e.g., `PhotoPrax/Views/ContentColumnView.swift`).
- In Xcode, select the file and check File Inspector > Target Membership. Ensure the app target is checked if the file should be built.

2) Avoid duplicate types
- Run a project-wide search for the type you’re editing (e.g., `struct ContentColumnView`).
- Ensure there is only one definition of the type in the app target.
- If you need a staging/experimental view, use a unique name (e.g., `ContentColumnViewStaging`) and keep it out of the app target unless necessary.

3) Prefer in-place edits
- Modify existing files with precise diffs.
- If a new file is absolutely required, give it a unique name and ensure it does not duplicate an existing type.

4) Clean after structural changes
- If files are added/removed/renamed, run Product > Clean Build Folder to clear stale artifacts.

5) Keep previews safe
- Previews should compile independently. If a dependency isn’t available, comment out the environment object or provide a minimal stub.

## Requesting Changes via Assistant
- When asking the assistant to modify code, include the exact file path and add: “Edit this file; do not create new files.”
- If the assistant cannot see the file, paste the file contents into the chat so it can be edited in-place.

## Troubleshooting
- "Multiple commands produce … .stringsdata": There are duplicate files or types. Remove the duplicate, verify target membership, and Clean Build Folder.
- "Cannot find 'TypeName' in scope": The file may not be in the target, or it was removed/renamed. Verify the path and target membership.

Thank you for helping keep the project clean and maintainable.
