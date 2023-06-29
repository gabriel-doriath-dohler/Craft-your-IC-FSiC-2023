# V-RISC-V at FSiC 2023

Slides for our talk at FSiC 2023 presenting our work on V-RISC-V.

## Dev Setup

Install nix, enable flakes and install direnv (with nix integration).

```console
direnv allow
nix build
```

### Git Hooks

```console
chmod u+x .githooks/*
git config --local core.hooksPath .githooks
```

# TODO

- [ ] Formatting LaTeX in a git hook
- [ ] Content license (CC BY? CC BY-SA?)
- [ ] Code license (Apache 2?)
