function printUsage

{

    echo ""

    echo "Usage:"

    echo "  $0 -i id_rsa -m 192.168.102.34 -u azureuser -n default -n monitoring --disable-host-key-checking"

    echo "  $0 --identity-file id_rsa --user azureuser --vmd-host 192.168.102.32"

    echo "  $0 --identity-file id_rsa --master-host 192.168.102.34 --user azureuser --vmd-host 192.168.102.32"

    echo "  $0 --identity-file id_rsa --master-host 192.168.102.34 --user azureuser --vmd-host 192.168.102.32"

    echo ""

    echo "Options:"

    echo "  -u, --user                      User name associated to the identifity-file"

    echo "  -i, --identity-file             RSA private key tied to the public key used to create the Kubernetes cluster (usually named 'id_rsa')"

    echo "  -m, --master-host               A master node's public IP or FQDN (host name starts with 'k8s-master-')"

    echo "  -d, --vmd-host                  The DVM's public IP or FQDN (host name starts with 'vmd-')"

    echo "  -n, --user-namespace            Collect logs for containers in the passed namespace (kube-system logs are always collected)"

    echo "  --all-namespaces                Collect logs for all containers. Overrides the user-namespace flag"

    echo "  --disable-host-key-checking     Sets SSH StrictHostKeyChecking option to \"no\" while the script executes. Use only when building automation in a save environment."

    echo "  -h, --help                      Print the command usage"

    exit 1

}





if [ "$#" -eq 0 ]

then

    printUsage

fi
