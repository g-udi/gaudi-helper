# Gaudi Helper

This is a helper that accompanies the [Gaudi project](https://github.com/ahmadassaf/gaudi). It is used to ensure you keep your templates list up to date by adding newly installed software to the list after the successful installation.

## Installation

You can install the helper by running the following command:

```sh
bash -c "$(curl -fsSL https://raw.githubusercontent.com/g-udi/gaudi-helper/master/install.sh)"
```

<img width="1143" alt="image" src="https://github.com/user-attachments/assets/b66803b8-ebaf-4301-9056-47d1bb2401c0">


## How it works

The helper works by using the `precmd` and `preexec` functions to detect when you have installed a new software and add it to the list.

The `precmd` function is executed before the command prompt is displayed and the `preexec` function is executed before each command is executed.

The helper is designed to be used with the `bash` shell, but it can be used with other shells like `zsh` by setting the `SHELL` environment variable to `zsh` in the `.bashrc` file.