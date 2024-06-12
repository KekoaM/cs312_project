#!/bin/sh
printf "======================================================\nCreating infra\n======================================================\n"

echo "tofu apply"
tofu apply

DOMAIN=$(tofu output -raw instance_public_dns)

printf "======================================================\nWaiting for vm\n======================================================\n"

sleep 25

printf "======================================================\nDeploying Minecraft Container\n======================================================\n"

echo "ansible-playbook -i inventory.aws_ec2.yaml playbook.yaml"
ansible-playbook -i inventory.aws_ec2.yaml playbook.yaml

printf "======================================================\nWaiting for Minecraft server to initialize\n======================================================\n"

sleep 30

printf "======================================================\nReady to play\n======================================================\n"

echo "nmap -sV -Pn -p T:25565 $DOMAIN"
nmap -sV -Pn -p T:25565 $DOMAIN
