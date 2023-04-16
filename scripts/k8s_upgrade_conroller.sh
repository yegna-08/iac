#!/usr/bin/env bash
# Upgrading K8s Control plane to latest stable 1.20 version

# Global variables
#Node name can be provided while running the script or the default is the HOSTNAME env variable
NODE_NAME=${1:-$HOSTNAME}
# KUBEADM_VERSION=${2?Error: Please provide kubeadm version}
# KUBELET_VERSION=${3?Error: Please provide kubelet version}
KUBEADM_VERSION="1.20.15"
KUBELET_VERSION="1.20.15"
KUBECTL_VERSION=${KUBELET_VERSION}


echo -e "Starting upgrade...\n"

# Draining control plane.
echo -e "> Draining control plane \e[1m${NODE_NAME}\e[0m \n"
sudo kubectl drain ${NODE_NAME} --ignore-daemonsets
echo
#
# Upgrading Kubeadm and showing the new version
echo -e "> Upgrading kubeadm...\n"
sudo yum install -y "kubeadm-${KUBEADM_VERSION}-0" --disableexcludes=kubernetes
echo  "Upgraded to version: `sudo kubeadm version`"
echo
#
# Verifying upgrade plan
echo -e "> Checking upgrade plan...\n"
sudo kubeadm upgrade plan "v${KUBEADM_VERSION}"
#
# Applying the upgrade
echo -e "> Aplying the upgrade ignoring automatic certificate renewal...\n"
sudo kubeadm upgrade apply "v${KUBEADM_VERSION}" --certificate-renewal=false --yes
echo
#
# Upgrade kubelet and kubectl
echo -e "> Upgrading kubelet and kubectl\n"
sudo yum install -y "kubelet-${KUBELET_VERSION}-0" "kubectl-${KUBELET_VERSION}-0" --disableexcludes=kubernetes
echo
#
# Restarting the kubelet
sudo systemctl daemon-reload && sudo systemctl restart kubelet
echo -e "daemon reloaded and kubelet restarted\n"
#
# Uncordoning the node
echo -e "> Bring the node back online by marking it schedulable...\n"
kubectl uncordon ${NODE_NAME}

#
echo -e "\nControl plane ${HOSTNAME} \e[32msuccessfuly\e[0m upgraded\n"