# Define variables
variable "kubernetes_version" {
  default = "1.22.5"
}

variable "node_count" {
  default = 1
}

variable "server_hostname" {
  default = "k8s-server"
}

variable "server_ip" {
  default = "10.0.0.10"
}

variable "ssh_private_key_path" {
  default = "/path/to/private/key"
}

# Configure provider
provider "ssh" {
  host = var.server_ip
  user = "root"
  private_key = file(var.ssh_private_key_path)
}

# Create server resource
resource "null_resource" "server" {
  provisioner "remote-exec" {
    inline = [
      "sudo hostnamectl set-hostname ${var.server_hostname}",
      "sudo apt-get update",
      "sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release",
      "sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg",
      "sudo echo 'deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main' | sudo tee /etc/apt/sources.list.d/kubernetes.list",
      "sudo apt-get update",
      "sudo apt-get install -y kubelet=${var.kubernetes_version}-00 kubeadm=${var.kubernetes_version}-00 kubectl=${var.kubernetes_version}-00",
    ]
  }
}

# Define Kubernetes provider
provider "kubernetes" {
  host                   = var.server_ip
  token_reviewer_jwt     = data.aws_iam_policy_document.kubernetes_token_reviewer.json
  load_config_file       = false
  host_key_file          = var.ssh_private_key_path
  exec {
    kind        = "SSH"
    command     = "sudo kubectl"
    args        = ["--kubeconfig=/etc/kubernetes/admin.conf"]
    environment = {
      "KUBECONFIG" = "/etc/kubernetes/admin.conf"
    }
  }
}

# Initialize the master node
resource "kubernetes_init_config" "master" {
  depends_on = [null_resource.server]

  node_count    = 1
  pod_cidr_block = "10.244.0.0/16"
}

# Join worker nodes to the cluster
resource "kubernetes_node" "worker" {
  count = var.node_count - 1 # -1 because the first node is the master

  depends_on = [kubernetes_init_config.master]

  connection {
    host        = var.server_ip
    type        = "ssh"
    user        = "root"
    private_key = file(var.ssh_private_key_path)
  }

  provisioner "file" {
    content     = kubernetes_init_config.master.join_command
    destination = "/tmp/join_command.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/join_command.sh",
      "/tmp/join_command.sh",
    ]
  }
}
