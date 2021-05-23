import configparser
import subprocess
import re
from pathlib import Path


def set_project_info():
    ini_file = open("../info.ini")

    config = configparser.ConfigParser()
    config.read_file(ini_file)
    ini_file.close()
    exit_code, git_description = subprocess.getstatusoutput(
        "git describe --tags --always --dirty"
    )
    if exit_code != 0:
        raise SystemExit(f"Failed to get git description: {git_description}")

    tag_prefix = config["git"]["tag prefix"]

    # adapted from https://regex101.com/r/Ly7O1x/3/
    # tested here https://regex101.com/r/0ZL2XU/1/
    pattern = (
        f"^(?:{tag_prefix})?"
        + r"(?P<major>0|[1-9]\d*)\.(?P<minor>0|[1-9]\d*)\.(?P<patch>0|[1-9]\d*)(?:-("
        r"?P<prerelease>(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\.(?:0|[1-9]\d*|\d*["
        r"a-zA-Z-][0-9a-zA-Z-]*))*))?(?:\+)?$"
    )
    match = re.search(pattern, git_description)
    assert match, f"Git tag '{git_description}' is not a semver string"

    global project, author, copyright, version, release
    project = config["project"]["name"]
    author = config["project"]["author"]
    copyright = f"{config['project']['copyright years']}, {author}"
    version = f"{match['major']}.{match['minor']}"
    release = f"{version}.{match['patch']}"
    try:
        release += f"-{match['prerelease']}"
    except IndexError:
        pass


def generate_rst_files():
    generated = Path(Path.cwd() / "generated")
    generated.mkdir(exist_ok=True)
    gitignore_file = generated / ".gitignore"
    if not gitignore_file.exists():
        gitignore_file.write_text("*\n")
    find_modules = generated / "find"
    find_modules.mkdir(exist_ok=True)
    util_modules = generated / "util"
    util_modules.mkdir(exist_ok=True)
    for file in (Path.cwd().parent / "modules").glob("*.cmake"):
        directory = find_modules if file.name.startswith("Find") else util_modules
        doc_file = directory / (file.name + ".rst")
        if not doc_file.exists():
            doc_file.write_text(f".. cmake-module:: ../../../modules/{file.name}\n")


# -- Project information -----------------------------------------------------

project = None
author = None
copyright = None
version = None
release = None

# -- General configuration ---------------------------------------------------

extensions = [
    "sphinxcontrib.moderncmakedomain",
    "sphinx_search.extension",
]
exclude_patterns = []
smartquotes = True
primary_domain = "cmake"

# -- HTML configuration ------------------------------------------------------

html_theme = "sphinx_rtd_theme"

# ----------------------------------------------------------------------------

set_project_info()
generate_rst_files()
