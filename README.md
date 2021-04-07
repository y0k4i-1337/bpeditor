# bpeditor
Batch editor for your Burp's project settings file

## Overview

The primary goal of this script is to batch edit some configurations in Burp that is currently not natively supported.
For instance, one cannot load a file containing a set of regex rules to Proxy's TLS Pass Through option.

By now, this tool only covers the case described above, although it could be extended to other similar cases as well.

## Usage

```
./bpeditor.sh -h
Usage: ./bpeditor.sh [-o FILE] INPUT PROJECT

  -o           write results to FILE
               By default, it makes a backup from PROJECT and overwrites it.

  INPUT        file containing the input data
  PROJECT      Burp's project settings

Example: ./bpeditor.sh ssl-pass-through-rules.txt myproject.json
```

## Quick Start

1. From Burp, go to Projects -> Project options -> Save project options.
2. Run the script like `./bpeditor.sh ssl-pass-through-rules.txt myproject.json`.
3. Reload options by going to Projects -> Project options -> Load project options.

## License

This project is licensed under MIT License. For more information, visit [LICENSE](LICENSE).
