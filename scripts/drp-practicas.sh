#!/usr/bin/env bash
# -------------------------------------------------------------
# DRP: Backup Module - Alumno E (Practicas)
# This script creates EC2 AMIs and syncs the S3 bucket.
# -------------------------------------------------------------

set -e

PROFILE="EquipoEUFV"
REGION="eu-south-2"
BUCKET_SOURCE="ufv-entregas-bucket"
BUCKET_BACKUP="ufv-entregas-bucket-drp-backup"

echo "[DRP] Iniciando proceso de Disaster Recovery para el modulo de Practicas..."

# 1. Recuperar los IDs de las instancias usando el Tag 'Name'
echo "[DRP] Localizando instancias de practicas..."
INSTANCE_1=$(aws ec2 describe-instances --profile $PROFILE --region $REGION --filters "Name=tag:Name,Values=ec2-practicas-1" "Name=instance-state-name,Values=running" --query "Reservations[0].Instances[0].InstanceId" --output text)
INSTANCE_2=$(aws ec2 describe-instances --profile $PROFILE --region $REGION --filters "Name=tag:Name,Values=ec2-practicas-2" "Name=instance-state-name,Values=running" --query "Reservations[0].Instances[0].InstanceId" --output text)

# 2. Crear AMIs (Snapshots) sin reiniciar la instancia
DATE_STAMP=$(date +%Y%m%d-%H%M)
if [ "$INSTANCE_1" != "None" ] && [ -n "$INSTANCE_1" ]; then
    echo "[DRP] Creando AMI de EC2Practicas1 ($INSTANCE_1)..."
    aws ec2 create-image --profile $PROFILE --region $REGION \
        --instance-id $INSTANCE_1 \
        --name "backup-practicas1-$DATE_STAMP" \
        --description "Backup DRP EC2Practicas1" \
        --no-reboot
fi

if [ "$INSTANCE_2" != "None" ] && [ -n "$INSTANCE_2" ]; then
    echo "[DRP] Creando AMI de EC2Practicas2 ($INSTANCE_2)..."
    aws ec2 create-image --profile $PROFILE --region $REGION \
        --instance-id $INSTANCE_2 \
        --name "backup-practicas2-$DATE_STAMP" \
        --description "Backup DRP EC2Practicas2" \
        --no-reboot
fi

# 3. Sincronizar S3 Bucket de entregas
echo "[DRP] Sincronizando bucket de S3 ($BUCKET_SOURCE) a local/backup..."
# Opción A: Backup a local
mkdir -p /tmp/s3-backup-practicas
aws s3 sync s3://$BUCKET_SOURCE /tmp/s3-backup-practicas --profile $PROFILE
# Opción B: Backup a otro bucket (Descomentar si existe)
# aws s3 sync s3://$BUCKET_SOURCE s3://$BUCKET_BACKUP --profile $PROFILE

echo "[DRP] Backup completado con exito."

# =====================================================================
# INSTRUCCIONES DE RESTAURACIÓN (Para incluir en la memoria DRP):
# =====================================================================
# 1. Restauración de EC2:
#    - Obtener el ID de la AMI creada mediante `aws ec2 describe-images`.
#    - Lanzar una nueva instancia EC2 usando esa AMI (vía consola o CLI `aws ec2 run-instances --image-id AMI_ID`).
#    - Asegurarse de adjuntarle el mismo Security Group y asociarla al Target Group del Load Balancer si ha cambiado la IP.
# 2. Restauración de S3:
#    - Si el bucket original se corrompe/borra, crear uno nuevo `aws s3 mb s3://nuevo-bucket-entregas`.
#    - Sincronizar de vuelta desde el backup: `aws s3 sync /tmp/s3-backup-practicas/ s3://nuevo-bucket-entregas`.
#    - Modificar el archivo de entorno o código (`practicas.js`) para que apunte al nuevo bucket si cambió el nombre.
