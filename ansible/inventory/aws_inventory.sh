#!/bin/bash
# =============================================================
# Inventario dinamico Ansible
# Usa IP PUBLICA para conectar (el portátil no está en la VPC)
# Grupos: windows, loadbalancer, database, webservers
# =============================================================

REGION="eu-south-2"

# Mapeo de perfiles a CIDR
declare -A PROFILES
PROFILES["AlumnoA"]="10.0.0.0/16"
PROFILES["AlumnoB"]="10.1.0.0/16"
PROFILES["AlumnoC"]="10.2.0.0/16"
PROFILES["AlumnoD"]="10.3.0.0/16"
PROFILES["AlumnoE"]="10.4.0.0/16"

TMPDIR_INV=$(mktemp -d)
trap "rm -rf $TMPDIR_INV" EXIT

get_instances() {
    local profile=$1
    local vpc_cidr=$2
    local outfile=$3

    local vpc_id
    vpc_id=$(aws ec2 describe-vpcs \
        --profile "$profile" --region "$REGION" \
        --filters "Name=cidr,Values=${vpc_cidr}" "Name=isDefault,Values=false" \
        --query 'Vpcs[0].VpcId' --output text 2>/dev/null)

    if [ -z "$vpc_id" ] || [ "$vpc_id" = "None" ] || [ "$vpc_id" = "null" ]; then
        echo "[]" > "$outfile"
        return
    fi

    # Recogemos IP privada, IP publica, nombre, plataforma
    aws ec2 describe-instances \
        --profile "$profile" \
        --region "$REGION" \
        --filters \
            "Name=vpc-id,Values=${vpc_id}" \
            "Name=instance-state-name,Values=running" \
        --query 'Reservations[*].Instances[*].{
            private_ip:PrivateIpAddress,
            public_ip:PublicIpAddress,
            name:Tags[?Key==`Name`]|[0].Value,
            platform:Platform}' \
        --output json 2>/dev/null \
    | python3 -c "
import sys, json
data = json.load(sys.stdin)
result = [i for sub in data for i in sub]
for r in result:
    r['profile'] = '$profile'
print(json.dumps(result))
" > "$outfile" 2>/dev/null || echo "[]" > "$outfile"
}

for profile in "${!PROFILES[@]}"; do
    get_instances "$profile" "${PROFILES[$profile]}" "$TMPDIR_INV/${profile}.json"
done

python3 - "$TMPDIR_INV" << 'PYEOF'
import json, sys, os, glob

inventory = {
    "_meta": {"hostvars": {}},
    "all": {"children": ["linux", "windows"]},
    "linux": {"children": ["loadbalancer", "database", "webservers"]},
    "windows": {"hosts": []},
    "loadbalancer": {"hosts": []},
    "database": {"hosts": []},
    "webservers": {"hosts": []}
}

def get_vars(private_ip, public_ip, name, profile, is_windows=False):
    connect_ip = public_ip if public_ip else private_ip
    
    if is_windows:
        return {
            "ansible_host": connect_ip,
            "ansible_user": "ansible",
            "ansible_password": "Airbusds2026",
            "ansible_connection": "winrm",
            "ansible_winrm_transport": "basic",
            "ansible_winrm_server_cert_validation": "ignore",
            "ansible_port": 5985,
            "ansible_become": False,
            "private_ip": private_ip,
            "public_ip": public_ip or "",
            "instance_name": name,
            "account": profile
        }
    else:
        return {
            "ansible_host": connect_ip,
            "ansible_user": "ansible",
            "ansible_password": "Airbusds2026",
            "ansible_become": True,
            "ansible_become_method": "sudo",
            "ansible_become_pass": "",
            "ansible_ssh_common_args": "-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null",
            "private_ip": private_ip,
            "public_ip": public_ip or "",
            "instance_name": name,
            "account": profile
        }

tmpdir = sys.argv[1]
files = glob.glob(os.path.join(tmpdir, "*.json"))

for f in files:
    with open(f) as file:
        try:
            instances = json.load(file)
        except json.JSONDecodeError:
            continue
            
        for inst in instances:
            priv = inst.get("private_ip") or ""
            pub  = inst.get("public_ip") or ""
            name = inst.get("name") or ""
            plat = (inst.get("platform") or "").lower()
            profile = inst.get("profile") or ""
            
            if not priv:
                continue
                
            key = priv
            
            is_windows = plat == "windows"
            
            # Clasificacion
            if profile == "AlumnoA":
                # AlumnoA is Windows AD/DNS
                inventory["windows"]["hosts"].append(key)
                is_windows = True
            elif profile == "AlumnoB":
                # AlumnoB has LB and Database
                name_lower = name.lower()
                if "db" in name_lower or "database" in name_lower or "postgres" in name_lower or "sql" in name_lower:
                    inventory["database"]["hosts"].append(key)
                else:
                    inventory["loadbalancer"]["hosts"].append(key)
            elif profile in ["AlumnoC", "AlumnoD", "AlumnoE"]:
                inventory["webservers"]["hosts"].append(key)
                
            inventory["_meta"]["hostvars"][key] = get_vars(priv, pub, name, profile, is_windows)

print(json.dumps(inventory, indent=2))
PYEOF
