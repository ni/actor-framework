# Actor Framework Release Workflows

This document contains information used to create the release artifacts using GitHub Actions workflows for the Actor Framework repository.

## Workflows

### 1. Create Distribution Artifact (`create-distribution-artifact.yml`)

Creates a structured artifact containing Actor Framework files organized in the correct directory layout for LabVIEW installation. The workflow yml can be found [here](/.github/workflows/create-distribution-artifact.yml).

**Triggers:**
- Manual dispatch via GitHub Actions UI
- Reusable workflow (called by other workflows)

**Artifact Structure:**
```
<root directory>/
├── vi.lib/
│   └── ActorFramework/          # From Core/ActorFramework/
├── resource/
│   ├── AFDebug/                 # From Core/AFDebug/
│   └── Framework/
│       └── Providers/           # From Providers/
└── menus/                       # From Core/Menus/
```

**Excluded Files:**
- `*.lvproj` - LabVIEW project files
- `*.vipb` - VI Package Builder files
- `*.aliases` - LabVIEW aliases files
- `*.lvlps` - LabVIEW project settings
- Paths listed in [`pipeline/config/artifact-exclusions.txt`](../../pipeline/config/artifact-exclusions.txt)

**Manual Usage:**
1. Go to Actions tab in GitHub
2. Select "Create Distribution Artifact" workflow
3. Click "Run workflow"
4. Download the `actor-framework-distribution` artifact

**Reusable Workflow Inputs:**
- `upload-artifact` (boolean, default: false) - Whether to upload as GitHub artifact

### 2. Create Release (`release.yml`)

Automatically creates a GitHub release with the distribution artifact when a version tag is pushed. The workflow yml can be found [here](/.github/workflows/release.yml).

**Triggers:**
- Push of tags matching pattern `v*.*.*` (e.g., `v2.0.0`, `v1.0.1`, `v2.0.0.5`, `v1.0.0.0-rc`)

**Process:**
1. Calls `create-distribution-artifact.yml` workflow
2. Downloads the created artifact
3. Compresses it into `actor-framework-distribution.zip`
4. Creates a GitHub release with:
   - The ZIP file as release asset
   - Auto-generated release notes

**Usage:**
```bash
# Create and push a version tag
git tag v2.0.0.18
git push origin v2.0.0.18

# The workflow runs automatically and creates the release
```

**Release Assets:**
- `actor-framework-distribution.zip` - Contains the complete framework in proper directory structure

## Configuration Files

### `pipeline/config/artifact-exclusions.txt`

Text file containing paths to exclude from the distribution artifact. See the file [here](../../pipeline/config/artifact-exclusions.txt).

**Format:**
- One path per line (relative to repository root)
- Lines starting with `#` are comments
- Empty lines are ignored
- Use backslashes for Windows paths: `Providers\Install Support`

**Example:**
```text
# Installation support files
Providers\Install Support

# Example exclusions (commented out)
# Examples\TestData
# Core\DeprecatedFeatures
```

**To add new exclusions:**
1. Edit `pipeline/config/artifact-exclusions.txt`
2. Add the path on a new line
3. Commit and push changes
4. Next workflow run will use updated exclusions

## Scripts

### `pipeline/scripts/Create_Distribution_Artifact.ps1`

PowerShell script that handles the actual file copying and artifact structure creation. See the script [here](../../pipeline/scripts/Create_Distribution_Artifact.ps1).

**Parameters:**
- `ExclusionFile` (string, optional) - Path to file containing exclusion patterns
  - Default: `$PSScriptRoot\..\config\artifact-exclusions.txt`

**Example:**
```powershell
# Use default exclusion file
.\pipeline\scripts\Create_Distribution_Artifact.ps1

# Use custom exclusion file
.\pipeline\scripts\Create_Distribution_Artifact.ps1 -ExclusionFile "path\to\custom-exclusions.txt"
```

**Logic:**
1. Reads exclusion paths from configuration file
2. Creates staging directory structure
3. Copies files from source directories
4. Excludes files based on:
   - File extensions: `*.lvproj`, `*.vipb`, `*.aliases`, `*.lvlps`
   - Paths listed in exclusion file
5. Maintains relative directory structure within each target location
6. Logs all excluded files and paths for troubleshooting

## Development Guidelines

### Adding New Exclusions

**Recommended Method:** Edit the exclusion configuration file

1. Open `pipeline/config/artifact-exclusions.txt`
2. Add new paths (one per line):
   ```text
   # Your comment explaining why
   Path\To\Exclude
   ```
3. Commit and push changes

**Alternative Method:** Override in workflow (not recommended for permanent exclusions)

```yaml
- name: Create framework artifact structure
  shell: pwsh
  run: |
    & "${{ github.workspace }}\pipeline\scripts\Create_Distribution_Artifact.ps1" -ExclusionFile "custom-exclusions.txt"
```

### Adding New File Extension Exclusions

Edit `Create_Distribution_Artifact.ps1` and add to `$excludeExtensions`:

```powershell
$excludeExtensions = @('*.lvproj', '*.vipb', '*.aliases', '*.lvlps', '*.your-extension')
```

### Adding New Source Directories

Update `Create_Distribution_Artifact.ps1`:

```powershell
# Add new directory creation
New-Item -ItemType Directory -Force -Path "$stagingDir\your\target\path"

# Add copy operation
Copy-WithExclusions -SourcePath "Source\Path" -DestPath "$stagingDir\your\target\path" -Label "Description"
```

### Testing Changes

Before pushing changes:

1. **Test locally:**
   ```powershell
   cd c:\dev\actor-framework
   .\pipeline\scripts\Create_Distribution_Artifact.ps1
   # Inspect artifact-staging/ directory
   ```

2. **Test via workflow:**
   - Go to Actions → "Create Distribution Artifact"
   - Click "Run workflow"
   - Download and verify artifact contents

3. **Test release workflow (use test tag):**
   ```bash
   git tag v0.0.0-test
   git push origin v0.0.0-test
   # Delete after testing: git push --delete origin v0.0.0-test
   ```

## Troubleshooting

### Artifact is missing files
- Check workflow logs for exclusion warnings
- Verify source directories exist and contain expected files
- Review `pipeline/config/artifact-exclusions.txt` for unintended exclusions
- Ensure file extensions aren't in the `$excludeExtensions` list

### Exclusions not working
- Verify exclusion file path is correct
- Check for typos in paths (case-sensitive on some systems)
- Ensure paths use backslashes: `Providers\Install Support`
- Review workflow logs for "Loaded X exclusion path(s)" message

### Release workflow not triggering
- Verify tag matches pattern `v*.*.*`
- Check that tag was pushed to remote: `git push origin <tagname>`
- Review Actions tab for any errors
- Ensure you have permissions to create releases

### Path issues on Windows
- The script normalizes paths (`/` → `\`)
- Use backslashes in exclusion file: `Providers\Install Support`
- Paths are relative to repository root
- Wildcards are supported in path matching

### Script fails to find exclusion file
- Default location: `pipeline\config\artifact-exclusions.txt`
- Verify file exists and is committed to repository
- Check file is not excluded by `.gitignore`
- Use `-ExclusionFile` parameter to specify custom path

## Related Documentation

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Reusable Workflows](https://docs.github.com/en/actions/using-workflows/reusing-workflows)
- [Creating Releases](https://docs.github.com/en/repositories/releasing-projects-on-github/managing-releases-in-a-repository)