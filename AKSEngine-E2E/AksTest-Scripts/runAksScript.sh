#!/bin/bash

function restore_ssh_config
{
    # Restore only if previously backed up
    if [[ -v SSH_CONFIG_BAK ]]; then
        if [ -f $SSH_CONFIG_BAK ]; then
            rm ~/.ssh/config
            mv $SSH_CONFIG_BAK ~/.ssh/config
        fi
    fi
    
    # Restore only if previously backed up
    if [[ -v SSH_KEY_BAK ]]; then
        if [ -f $SSH_KEY_BAK ]; then
            rm ~/.ssh/id_rsa
            mv $SSH_KEY_BAK ~/.ssh/id_rsa
            # Remove if empty
            if [ -a ~/.ssh/id_rsa -a ! -s ~/.ssh/id_rsa ]; then
                rm ~/.ssh/id_rsa
            fi
        fi
    fi
}

# Restorey SSH config file always, even if the script ends with an error
trap restore_ssh_config EXIT


function printUsage
{
    echo ""
    echo "Usage:"
    echo "  $0 -i id_rsa -d 192.168.102.34 -u azureuser --file aks_file --tenant-Id tenant-id --subscription-id subscription-id --disable-host-key-checking"
    echo ""
    echo "Options:"
    echo "  -u, --user                      User name associated to the identifity-file"
    echo "  -i, --identity-file             RSA private key tied to the public key used to create the Kubernetes cluster (usually named 'id_rsa')"
    echo "  -d, --vmd-host                  The DVM's public IP or FQDN (host name starts with 'vmd-')"
    echo "  -t, --tenant-id                 The Tenant ID used by aks engine"
    echo "  -s, --subscription-id           The Subscription ID used by aks engine"
    echo "  -f, --file                      Aks Engine Scale or Upgrade script to run on dvm"
    echo "  -p, --parameter                 For scale node_count should be passed and for upgrade version should be passed"
    echo "  --disable-host-key-checking     Sets SSH StrictHostKeyChecking option to \"no\" while the script executes. Use only when building automation in a save environment."
    echo "  -h, --help                      Print the command usage"
    exit 1
}

function download_scripts
{
    ARTIFACTSURL=$1
    script=$2
    
    echo "[$(date +%Y%m%d%H%M%S)][INFO] Pulling aks script from this repo: $ARTIFACTSURL"
        
    curl -fs $ARTIFACTSURL -o $SCRIPTSFOLDER/$script
        
    if [ ! -f $SCRIPTSFOLDER/$script ]; then
        echo "[$(date +%Y%m%d%H%M%S)][ERROR] Required script not available. URL: $ARTIFACTSURL"
        exit 1
    fi
    
}


if [ "$#" -eq 0 ]
then
    printUsage
fi

# Handle named parameters
while [[ "$#" -gt 0 ]]
do
    case $1 in
        -i|--identity-file)
            IDENTITYFILE="$2"
            shift 2
        ;;
        -m|--master-host)
            MASTER_HOST="$2"
            shift 2
        ;;
        -d|--vmd-host)
            DVM_HOST="$2"
            shift 2
        ;;
        -u|--user)
            USER="$2"
            shift 2
        ;;
        -t|--tenant-id)
            TENANT_ID="$2"
            shift 2
        ;;
        -s|--subscription-id)
            SUBSCRIPTION_ID="$2"
            shift 2
        ;;
        -f|--file)
            FILE="$2"
            shift 2
        ;;
        -p|--parameter)
            PARAMETER="$2"
            shift 2
        ;;
        --disable-host-key-checking)
            STRICT_HOST_KEY_CHECKING="no"
            shift
        ;;
        -h|--help)
            printUsage
        ;;
        *)
            echo ""
            echo "[ERR] Incorrect option $1"
            printUsage
        ;;
    esac
done

# Validate input
if [ -z "$USER" ]
then
    echo ""
    echo "[ERR] --user is required"
    printUsage
fi

if [ -z "$IDENTITYFILE" ]
then
    echo ""
    echo "[ERR] --identity-file is required"
    printUsage
fi

if [ -z "$DVM_HOST" ]
then
    echo ""
    echo "[ERR] --vmd-host should be provided"
    printUsage
fi

if [ ! -f $IDENTITYFILE ]
then
    echo ""
    echo "[ERR] identity-file not found at $IDENTITYFILE"
    printUsage
    exit 1
else
    cat $IDENTITYFILE | grep -q "BEGIN \(RSA\|OPENSSH\) PRIVATE KEY" \
    || { echo "The identity file $IDENTITYFILE is not a RSA Private Key file."; echo "A RSA private key file starts with '-----BEGIN [RSA|OPENSSH] PRIVATE KEY-----''"; exit 1; }
fi

# Print user input
echo ""
echo "user:             $USER"
echo "identity-file:    $IDENTITYFILE"
echo "vmd-host:         $DVM_HOST"
echo "tenant-id:        $TENANT_ID"
echo "subscription-id:  $SUBSCRIPTION_ID"
echo "file:             $FILE"
echo "parameter:        $PARAMETER"
echo ""


NOW=`date +%Y%m%d%H%M%S`
SCRIPTSFOLDER="./AksEngineScripts/scripts"

if [ ! -d $SCRIPTSFOLDER ]; then
    mkdir -p $SCRIPTSFOLDER
fi
echo "[INFO] $SCRIPTSFOLDER"

# Backup .ssh/config
SSH_CONFIG_BAK=~/.ssh/config.$NOW
if [ ! -f ~/.ssh/config ]; then touch ~/.ssh/config; fi
mv ~/.ssh/config $SSH_CONFIG_BAK;

# Backup .ssh/id_rsa
SSH_KEY_BAK=~/.ssh/id_rsa.$NOW
if [ ! -f ~/.ssh/id_rsa ]; then touch ~/.ssh/id_rsa; fi
mv ~/.ssh/id_rsa $SSH_KEY_BAK;
cp $IDENTITYFILE ~/.ssh/id_rsa

echo "Host *" >> ~/.ssh/config
echo "    StrictHostKeyChecking $STRICT_HOST_KEY_CHECKING" >> ~/.ssh/config
echo "    UserKnownHostsFile /dev/null" >> ~/.ssh/config
echo "    LogLevel ERROR" >> ~/.ssh/config

echo "[$(date +%Y%m%d%H%M%S)][INFO] Testing SSH keys"
ssh -q $USER@$DVM_HOST "exit"

ROOT_PATH=/home/azureuser/src/github.com/Azure/aks-engine
FILENAME=$(basename $FILE)
download_scripts $FILE $FILENAME

scp -q -i $IDENTITYFILE $SCRIPTSFOLDER/*.sh $USER@$DVM_HOST:$ROOT_PATH

if [ $FILENAME == "aksEngineScale.sh" ] ; then
    ssh -q -t $USER@$DVM_HOST "sudo chmod 744 $FILENAME; ./$FILENAME --tenant-id $TENANT_ID --subscription-id $SUBSCRIPTION_ID --node-count $PARAMETER ;"
fi

if [ $FILENAME == "aksEngineUpgrade.sh" ] ; then
    ssh -q -t $USER@$DVM_HOST "sudo chmod 744 $FILENAME; ./$FILENAME --tenant-id $TENANT_ID --subscription-id $SUBSCRIPTION_ID --upgrade-version $PARAMETER ;"
fi





