"""Check requirements of virtual projects that have no installed METADATA."""
import argparse
import importlib.metadata as metadata
import json
from pathlib import Path
import sys
import tomllib

from packaging.markers import default_environment
from packaging.requirements import Requirement
from packaging.specifiers import SpecifierSet
from packaging.utils import canonicalize_name

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("projects_json", type=Path)
parser.add_argument("--installed", action="store_true", help="Also validate all installed distribution requirements")
args = parser.parse_args()
marker_environment = default_environment()
checks = []
failures = []
configuration = json.loads(args.projects_json.read_text())
# A list remains accepted for standalone virtual-project checks.
if isinstance(configuration, list):
    projects = configuration
    dependency_spec = {}
else:
    projects = configuration["projects"]
    dependency_spec = configuration.get("dependencies", {})
requested_extras = {
    canonicalize_name(name): set(extras)
    for name, extras in dependency_spec.items()
}
for specification in projects:
    manifest = Path(specification["manifest"])
    project = tomllib.loads(manifest.read_text())["project"]
    project_name = canonicalize_name(project["name"])
    extras = set(specification.get("extras", []))
    optional = project.get("optional-dependencies", {})
    # Follow a virtual project's self-references, e.g. project[rl] -> project[skrl].
    previous = None
    while previous != extras:
        previous = extras.copy()
        entries = list(project.get("dependencies", []))
        for extra in sorted(extras):
            entries.extend(optional[extra])
        for text in entries:
            requirement = Requirement(text)
            contexts = [dict(marker_environment, extra=extra) for extra in ["", *sorted(extras)]]
            active = requirement.marker is None or any(requirement.marker.evaluate(context) for context in contexts)
            if active and canonicalize_name(requirement.name) == project_name:
                extras.update(requirement.extras)
    requires_python = project.get("requires-python")
    if requires_python and not SpecifierSet(requires_python).contains(marker_environment["python_full_version"]):
        failures.append(f"{project_name}: Python {marker_environment['python_full_version']} does not satisfy {requires_python}")
    for text in sorted(set(entries)):
        requirement = Requirement(text)
        contexts = [dict(marker_environment, extra=extra) for extra in ["", *sorted(extras)]]
        if requirement.marker is not None and not any(requirement.marker.evaluate(context) for context in contexts):
            continue
        if canonicalize_name(requirement.name) == project_name:
            continue
        requested_extras.setdefault(canonicalize_name(requirement.name), set()).update(requirement.extras)
        try:
            version = metadata.version(requirement.name)
        except metadata.PackageNotFoundError:
            failures.append(f"{project_name}: missing {requirement.name}")
            continue
        if requirement.specifier and not requirement.specifier.contains(version, prereleases=True):
            failures.append(f"{project_name}: {requirement.name} {version} does not satisfy {requirement.specifier}")
        checks.append({"project": project_name, "requirement": text, "installed_version": version})
installed_count = None
if args.installed:
    installed = {}
    for distribution in metadata.distributions():
        name = canonicalize_name(distribution.metadata["Name"])
        if name in installed and distribution.version != installed[name].version:
            failures.append(f"{name}: multiple installed versions")
        installed[name] = distribution
    installed_count = len(installed)

    def active(requirement, name):
        contexts = [dict(marker_environment, extra=extra)
                    for extra in ["", *sorted(requested_extras.get(name, set()))]]
        return requirement.marker is None or any(requirement.marker.evaluate(context) for context in contexts)

    # Follow extra requests through installed package metadata to a fixed point.
    # This catches transitive requirements, including newton's importer extras.
    changed = True
    while changed:
        changed = False
        for name, distribution in installed.items():
            for text in distribution.requires or []:
                requirement = Requirement(text)
                if not active(requirement, name):
                    continue
                extras = requested_extras.setdefault(canonicalize_name(requirement.name), set())
                before = len(extras)
                extras.update(requirement.extras)
                changed |= len(extras) != before

    for name, distribution in sorted(installed.items()):
        requires_python = distribution.metadata.get("Requires-Python")
        if requires_python and not SpecifierSet(requires_python).contains(marker_environment["python_full_version"]):
            failures.append(f"{name}: Python {marker_environment['python_full_version']} does not satisfy {requires_python}")
        for text in distribution.requires or []:
            requirement = Requirement(text)
            if not active(requirement, name):
                continue
            dependency = installed.get(canonicalize_name(requirement.name))
            if dependency is None:
                failures.append(f"{name}: missing {requirement.name}")
                continue
            version = dependency.version
            if requirement.specifier and not requirement.specifier.contains(version, prereleases=True):
                failures.append(f"{name}: {requirement.name} {version} does not satisfy {requirement.specifier}")
            checks.append({"project": name, "requirement": text, "installed_version": version})
result = {"status": "failed" if failures else "passed", "checked_requirements": len(checks),
          "installed_distributions": installed_count, "failures": failures}
print(json.dumps(result, indent=2))
sys.exit(bool(failures))
