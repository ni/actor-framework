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
- `Providers\Install Support\` - Installation support files

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
- Push of tags matching pattern `v*.*.*` (e.g., `v2.0.0`, `v1.0.1`, `v.2.0.0.5`, `v1.0.0.0-rc`)

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

## Scripts

### `pipeline/scripts/Create_Distribution_Artifact.ps1`

PowerShell script that handles the actual file copying and artifact structure creation.

**Parameters:**
- `ExcludePaths` (string) - Newline-separated list of paths to exclude (relative to repo root)

**Example:**
```powershell
.\pipeline\scripts\Create_Distribution_Artifact.ps1 -ExcludePaths "Providers\Install Support"
```

**Logic:**
1. Creates staging directory structure
2. Copies files from source directories
3. Excludes files based on:
   - File extensions (*.lvproj, *.vipb, *.aliases, *.lvlps)
   - Specific paths (configurable via parameter)
4. Maintains relative directory structure within each target location

## Development Guidelines

### Adding New Exclusions

To exclude additional files or directories:

1. **For specific paths:** Update the workflow YAML files to pass additional exclusions:
   ```yaml
   run: |
     & "${{ github.workspace }}\pipeline\scripts\Create_Distribution_Artifact.ps1" -ExcludePaths "Providers\Install Support`nCore\Examples"
   ```

2. **For file patterns:** Edit `Create_Distribution_Artifact.ps1` and add to `$excludeExtensions`:
   ```powershell
   $excludeExtensions = @('*.lvproj', '*.vipb', '*.aliases', '*.lvlps', '*.your-extension')
   ```

### Adding New Source Directories

To include additional directories in the artifact:

1. Update `Create_Distribution_Artifact.ps1`:
   ```powershell
   # Add new directory creation
   New-Item -ItemType Directory -Force -Path "$stagingDir\your\target\path"
   
   # Add copy operation
   Copy-WithExclusions -SourcePath "Source\Path" -DestPath "$stagingDir\your\target\path" -Label "Description"
   ```

## Troubleshooting

### Artifact is missing files
- Check workflow logs for exclusion warnings
- Verify source directories exist and contain expected files
- Ensure file extensions aren't in the exclusion list

### Release workflow not triggering
- Verify tag matches pattern `v*.*.*`
- Check that tag was pushed to remote: `git push origin <tagname>`
- Review Actions tab for any errors

### Path issues on Windows
- The script normalizes paths (`/` → `\`)
- Use backslashes in YAML: `Providers\Install Support`
- Paths are relative to repository root

## Related Documentation

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Reusable Workflows](https://docs.github.com/en/actions/using-workflows/reusing-workflows)
- [Creating Releases](https://docs.github.com/en/repositories/releasing-projects-on-github/managing-releases-in-a-repository)