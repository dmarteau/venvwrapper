# Venvwrapper 

Very simple port of Doug Hellmann's virtualenvwrapper that uses
python 3 venv module.

It supports basics virtualenvwrapper-like commands:

- workon
- mkvenv (like mkvirtualenv) 
- rmvenv (like rmvirtualenv)
- Tab completion

For more informations, refer to the [virtualenwrapper documentation](https://virtualenvwrapper.readthedocs.io/en/latest/)

## Installation

Copy the venvwrapper to any place accessible to your shell startup script - usually `/usr/local/bin/`

Add the following to your shell startup:

```
export WORKON_HOME=~/.venvs
mkdir -p $WORKON_HOME
# Optionnaly change your default python 
# export VENVWRAPPER_YTHON="/usr/bin/python3.8"
source /usr/local/bin/venvwrapper.sh
```


