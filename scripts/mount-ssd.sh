#!/bin/bash
set -euo pipefail

DISK="/dev/nvme1n1"
PART="${DISK}p1"
LABEL="ssd"
MOUNT="/mnt/ssd"
UUID="0950fb98-ce9b-43f6-bde5-5fe2ce046339"
FSTAB_ENTRY="UUID=${UUID} ${MOUNT} ext4 defaults,nofail 0 2"

if [ "$EUID" -eq 0 ]; then
  echo "Run as regular user, not root (sudo is used internally)"
  exit 1
fi

if [ ! -b "$DISK" ]; then
  echo "ERROR: $DISK not found"
  exit 1
fi

if ! mountpoint -q "$MOUNT"; then
  if ! sudo blkid "$PART" >/dev/null 2>&1; then
    echo "Partitioning $DISK (GPT, single ext4 partition)..."
    sudo parted -s "$DISK" mklabel gpt mkpart primary ext4 0% 100%
    sudo partprobe "$DISK"
    sleep 2
  fi

  if ! sudo blkid -s UUID -o value "$PART" >/dev/null 2>&1; then
    echo "Formatting $PART as ext4 (label=${LABEL})..."
    sudo mkfs.ext4 -F -L "$LABEL" "$PART"
  fi

  ACTUAL_UUID="$(sudo blkid -s UUID -o value "$PART")"
  if [ "$ACTUAL_UUID" != "$UUID" ]; then
    echo "WARNING: UUID mismatch (expected $UUID, got $ACTUAL_UUID). Update README + fstab entry."
    FSTAB_ENTRY="UUID=${ACTUAL_UUID} ${MOUNT} ext4 defaults,nofail 0 2"
  fi

  sudo mkdir -p "$MOUNT"
  grep -q "$ACTUAL_UUID" /etc/fstab || echo "$FSTAB_ENTRY" | sudo tee -a /etc/fstab >/dev/null
  sudo mount -a
  sudo chown "$USER:$USER" "$MOUNT"
else
  echo "$MOUNT already mounted, verifying fstab..."
  ACTUAL_UUID="$(sudo blkid -s UUID -o value "$PART")"
  grep -q "$ACTUAL_UUID" /etc/fstab || echo "$FSTAB_ENTRY" | sudo tee -a /etc/fstab >/dev/null
fi

df -h "$MOUNT"
mount | grep nvme1n1
