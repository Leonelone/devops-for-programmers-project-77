#!/usr/bin/env python3
import json
import subprocess
from pathlib import Path
from jinja2 import Template

ROOT = Path(__file__).resolve().parents[2]
TERRAFORM_DIR = ROOT / "terraform"
TEMPLATE_FILE = ROOT / "ansible" / "inventory.ini.j2"
OUTPUT_FILE = ROOT / "ansible" / "inventory.ini"
GROUP_VARS_ALL = ROOT / "ansible" / "group_vars" / "all"


def terraform_output(name: str):
    result = subprocess.run(
        ["terraform", "output", "-json", name],
        cwd=str(TERRAFORM_DIR),
        capture_output=True,
        text=True,
        check=True,
    )
    return json.loads(result.stdout)


def main():
    web_ips = terraform_output("web_public_ips")
    if isinstance(web_ips, dict) and "value" in web_ips:
        web_ips = web_ips["value"]

    try:
        app_domain = terraform_output("app_domain")
        if isinstance(app_domain, dict) and "value" in app_domain:
            app_domain = app_domain["value"]
    except subprocess.CalledProcessError:
        app_domain = None

    with open(TEMPLATE_FILE) as f:
        template = Template(f.read())
    rendered = template.render(web_ips=web_ips)
    with open(OUTPUT_FILE, "w") as f:
        f.write(rendered)
    print(f"Inventory written to {OUTPUT_FILE}")

    # Write group vars with domain if available
    if app_domain:
        GROUP_VARS_ALL.mkdir(parents=True, exist_ok=True)
        (GROUP_VARS_ALL / "domain.yml").write_text(f"app_domain: {app_domain}\n")
        print(f"Group vars written to {GROUP_VARS_ALL / 'domain.yml'}")


if __name__ == "__main__":
    main()

