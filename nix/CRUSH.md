# Nix Configuration

This repository contains my personal Nix configuration for both NixOS and Home Manager.

## Structure

- `machines/`: Machine-specific configurations
- `modules/`: Reusable NixOS and Home Manager modules (all shared config lives here now)
- `overlays/`: Custom package overlays
- `lib/`: Helper functions and utilities
- `scripts/`: Utility scripts

## Helper Functions

This configuration uses helper functions to make imports cleaner and more maintainable. Always prefer these helper functions over relative paths.

### Available Helper Functions

- `self.lib.modules.getNixosModule "path"`: Import a NixOS module
- `self.lib.modules.getNixosModuleDir "path"`: Import a NixOS module directory
- `self.lib.modules.getHomeModule "path"`: Import a Home Manager module
- `self.lib.modules.getHomeModuleDir "path"`: Import a Home Manager module directory

## Development

This repository includes Cursor IDE configuration with snippets and linting rules to encourage best practices:

- Snippets for common Nix patterns
- Linting rules to encourage using helper functions
- Formatting rules for consistent code style

## License

This configuration is provided as-is with no warranty. Feel free to use it as inspiration for your own Nix configuration.
