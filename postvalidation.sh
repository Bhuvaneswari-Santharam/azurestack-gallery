#! /bin/bash

function printUsage
{
    echo "      Usage:"          
    echo "      $FILENAME --identity-file id_rsa --host 192.168.102.34 --user azureuser"
    echo  "" 
    echo "            -i, --identity-file                         the RSA Private Key filefile to connect the kubernetes master VM, it starts with -----BEGIN RSA PRIVATE KEY-----"
    echo "            -h, --host                                  public ip or FQDN of the Kubernetes cluster master VM. The VM name starts with k8s-master- "
    echo "            -u, --user                                  user name of the Kubernetes cluster master VM "
    exit 1
}

FILENAME=$0

while [[ "$#" -gt 0 ]]
do
case $1 in
    -i|--identity-file)
    IDENTITYFILE="$2"
    ;;
    -h|--host)
    HOST="$2"
    ;;
    -u|--user)
    AZUREUSER="$2"
    ;;
    *)
    echo ""    
    echo "Incorrect parameter $1"    
    echo ""
    printUsage
    ;;
esac

if [ "$#" -ge 2 ]
then
shift 2
else
shift
fi
done

echo "identity-file: $IDENTITYFILE"
echo "host: $HOST"
echo "user: $AZUREUSER"

IDENTITYFILEBACKUPPATH="/home/$AZUREUSER/IDENTITYFILEBACKUP"

ssh -t -i $IDENTITYFILE $AZUREUSER@$HOST "if [ -f /home/$AZUREUSER/.ssh/id_rsa ]; then mkdir -p $IDENTITYFILEBACKUPPATH;  sudo mv /home/$AZUREUSER/.ssh/id_rsa $IDENTITYFILEBACKUPPATH; fi;"
scp -i $IDENTITYFILE $IDENTITYFILE $AZUREUSER@$HOST:/home/$AZUREUSER/.ssh/id_rsa


ssh -t -i $IDENTITYFILE $AZUREUSER@$HOST "if [ -f /home/$AZUREUSER/.ssh/id_rsa ]; then sudo chmod 400 /home/$AZUREUSER/.ssh/id_rsa; cd /home/$AZUREUSER; curl -O https://raw.githubusercontent.com/LingyunSu/AzureStack-QuickStart-Templates/master/k8s-post-deployment-validation/install_helm_test.sh; sudo chmod 744 install_helm_test.sh;fi;"
ssh -t -i $IDENTITYFILE $AZUREUSER@$HOST "cd /home/$AZUREUSER; ./install_helm_test.sh;"

ssh -t -i $IDENTITYFILE $AZUREUSER@$HOST "if [ -f /home/$AZUREUSER/.ssh/id_rsa ]; then sudo chmod 400 /home/$AZUREUSER/.ssh/id_rsa; cd /home/$AZUREUSER; curl -O https://raw.githubusercontent.com/Bhuvaneswari-Santharam/AzureStack-QuickStart-Templates/master/k8s-post-deployment-validation/install_wordpress_on_kubernete_in_helm_test.sh; sudo chmod 744 install_wordpress_on_kubernete_in_helm_test.sh;fi;"
ssh -t -i $IDENTITYFILE $AZUREUSER@$HOST "cd /home/$AZUREUSER; ./install_wordpress_on_kubernete_in_helm_test.sh;"
ssh -t -i $IDENTITYFILE $AZUREUSER@$HOST "if [ -f /home/$AZUREUSER/.ssh/id_rsa ]; then sudo chmod 400 /home/$AZUREUSER/.ssh/id_rsa; cd /home/$AZUREUSER; curl -O https://raw.githubusercontent.com/LingyunSu/AzureStack-QuickStart-Templates/master/k8s-post-deployment-validation/helm_create_helloworld_chart_test.sh; sudo chmod 744 helm_create_helloworld_chart_test.sh;fi;"

ssh -t -i $IDENTITYFILE $AZUREUSER@$HOST "cd /home/$AZUREUSER; ./helm_create_helloworld_chart_test.sh;"

CURRENTDATE=$(date +"%Y-%m-%d-%H-%M-%S-%3N")
LOGFILEFOLDER="PostValidationLogs$CURRENTDATE"
mkdir -p $LOGFILEFOLDER


ssh -t -i $IDENTITYFILE $AZUREUSER@HOST "cd /home/$AZUREUSER; mkdir -p var_log"
ssh -t -i $IDENTITYFILE $AZUREUSER@$HOST "cp -R /var/log /home/$AZUREUSER/var_log;"
ssh -t -i $IDENTITYFILE $AZUREUSER@$HOST "tar -zcvf var_log.tar.gz var_log;"

scp -r -i $IDENTITYFILE $AZUREUSER@$HOST:/home/$AZUREUSER/var_log.tar.gz $LOGFILEFOLDER

echo "Kubernetes Post Validation logs are copied into $LOGFILEFOLDER"
