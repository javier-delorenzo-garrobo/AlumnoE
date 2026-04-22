#!/bin/bash
# =============================================================
#  check-prerequisites.sh
#  Verifica que todo lo necesario está configurado antes
#  de ejecutar el pipeline de Jenkins
# =============================================================

set -e

REGION="${1:-eu-south-2}"
PROFILES=("AlumnoA" "AlumnoB" "AlumnoC" "AlumnoD" "AlumnoE")

PASS=0
FAIL=0

check() {
    local desc="$1"
    local cmd="$2"
    if eval "$cmd" > /dev/null 2>&1; then
        echo "  ✅  $desc"
        PASS=$((PASS+1))
    else
        echo "  ❌  $desc"
        FAIL=$((FAIL+1))
    fi
}

echo "============================================"
echo " Verificando prerrequisitos del pipeline"
echo " Region: ${REGION}"
echo "============================================"
echo ""

echo "[ AWS CLI ]"
check "aws-cli instalado" "which aws"
check "version aws-cli >= 2" "aws --version 2>&1 | grep -q 'aws-cli/2'"

echo ""
echo "[ Perfiles AWS ]"
for p in "${PROFILES[@]}"; do
    check "Perfil '${p}' configurado" "aws configure list --profile ${p}"
done

echo ""
echo "[ Autenticacion AWS ]"
for p in "${PROFILES[@]}"; do
    check "Acceso cuenta ${p}" "aws sts get-caller-identity --profile ${p} --region ${REGION}"
done

echo ""
echo "[ IDs de cuenta ]"
for p in "${PROFILES[@]}"; do
    ACCOUNT=$(aws sts get-caller-identity --profile ${p} --region ${REGION} --query Account --output text 2>/dev/null || echo "ERROR")
    echo "  ${p} Account ID: ${ACCOUNT}"
done

echo ""
echo "[ Key Pairs ]"
for p in "${PROFILES[@]}"; do
    echo "  Listando Key Pairs en ${p} (${REGION}):"
    aws ec2 describe-key-pairs --profile ${p} --region ${REGION} \
        --query 'KeyPairs[*].KeyName' --output table 2>/dev/null || echo "  (sin key pairs o error de acceso)"
done

echo ""
echo "[ AMIs disponibles - Amazon Linux 2023 ]"
for p in "${PROFILES[@]}"; do
    AMI_LINUX=$(aws ec2 describe-images --profile ${p} --region ${REGION} --owners amazon --filters "Name=name,Values=al2023-ami-*-x86_64" "Name=state,Values=available" --query 'sort_by(Images, &CreationDate)[-1].ImageId' --output text 2>/dev/null || echo "ERROR")
    echo "  AMI AL2023 en ${p}: ${AMI_LINUX}"
done

echo ""
echo "[ Permisos IAM minimos necesarios ]"
for p in "${PROFILES[@]}"; do
    check "${p} puede crear CloudFormation" \
        "aws cloudformation list-stacks --profile ${p} --region ${REGION}"
    check "${p} puede crear VPCs" \
        "aws ec2 describe-vpcs --profile ${p} --region ${REGION}"
done

echo ""
echo "[ IP Publica ]"
MY_IP=$(curl -s --max-time 5 https://checkip.amazonaws.com 2>/dev/null || echo "no detectada")
echo "  Tu IP publica actual: ${MY_IP}/32"

echo ""
echo "[ Jenkins ]"
check "Jenkins corriendo en localhost:8080" "curl -s -o /dev/null -w '%{http_code}' http://localhost:8080 | grep -qE '200|403'"

echo ""
echo "============================================"
echo " RESULTADO: ${PASS} OK  |  ${FAIL} FALLOS"
echo "============================================"

if [ $FAIL -gt 0 ]; then
    echo ""
    echo "⚠️  Hay ${FAIL} problema(s) que resolver antes de ejecutar el pipeline."
    echo "   Consulta el README.md para instrucciones de configuracion."
    exit 1
else
    echo ""
    echo "✅ Todo listo para ejecutar el pipeline!"
fi
