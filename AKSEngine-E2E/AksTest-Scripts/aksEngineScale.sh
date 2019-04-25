#! /bin/bash
set -e

log_level() 
{ 
    case "$1" in
       -e) echo "$(date) [Error]  : " ${@:2}
          ;;
       -w) echo "$(date) [Warning]: " ${@:2}
          ;;       
       -i) echo "$(date) [Info]   : " ${@:2}
          ;;
       *)  echo "$(date) [Verbose]: " ${@:2}
          ;;
    esac
}


while [[ "$#" -gt 0 ]]

do

    case $1 in

        --tenant-id)

            TENANT_ID="$2"

            shift 2

        ;;

        --subscription-id)

            TENANT_SUBSCRIPTION_ID="$2"

            shift 2

        ;;

        --node-count)

            NODE_COUNT="$2"

            shift 2

        ;;
        *)

    esac

done



# Validate input

if [ -z "$TENANT_ID" ]

then

    echo ""

    echo "[ERR] --tenant-id is required"

    printUsage

fi



if [ -z "$TENANT_SUBSCRIPTION_ID" ]

then

    echo ""

    echo "[ERR] --subscription-id is required"

    printUsage

fi


if [ -z "$NODE_COUNT" ]

then

    echo ""

    echo "[ERR] --node-count is required"

    printUsage

fi



# Basic details of the system
log_level -i "Running  script as : $(whoami)"

log_level -i "System information: $(sudo uname -a)"


ROOT_PATH=/home/azureuser/src/github.com/Azure/aks-engine
cd $ROOT_PATH

log_level -i "Getting Resource group and region"

export RESOURCE_GROUP=`ls -dt1 _output/* | head -n 1 | cut -d/ -f2 | cut -d. -f1`
export REGION=`ls -dt1 _output/* | head -n 1 | cut -d/ -f2 | cut -d- -f2`
export APIMODEL_FILE=$RESOURCE_GROUP.json

if [ $RESOURCE_GROUP == "" ] ; then
    log_level -i "Resource group not found.Scale can not be performed"
    exit 1
fi

if [ $REGION == "" ] ; then
    log_level -i "Region not found.Scale can not be performed"
    exit 1
fi


cd $ROOT_PATH/_output

sudo chown -R azureuser $ROOT_PATH

CLIENT_ID=$(cat $ROOT_PATH/_output/$APIMODEL_FILE | jq '.properties.servicePrincipalProfile.clientId'| tr -d '"')
FQDN_ENDPOINT_SUFFIX=$(cat $ROOT_PATH/_output/$APIMODEL_FILE | jq '.properties.customCloudProfile.environment.resourceManagerVMDNSSuffix' | tr -d '"')
IDENTITY_SYSTEM=$(cat $ROOT_PATH/_output/$APIMODEL_FILE | jq '.properties.customCloudProfile.identitySystem' | tr -d '"')
AUTH_METHOD=$(cat $ROOT_PATH/_output/$APIMODEL_FILE | jq '.properties.customCloudProfile.authenticationMethod' | tr -d '"')
AZURE_ENV=$(cat $ROOT_PATH/_output/$APIMODEL_FILE | jq '.properties.customCloudProfile.environment.name' | tr -d '"')

echo "CLIENT_ID: $CLIENT_ID"

if [ $CLIENT_ID == "" ] ; then
    log_level -i "Client ID not found.Scale can not be performed"
    exit 1
fi

export CLIENT_ID=$CLIENT_ID
export CLIENT_SECRET=""
export NAME=$RESOURCE_GROUP
export REGION=$REGION
export TENANT_ID=$TENANT_ID
export SUBSCRIPTION_ID=$TENANT_SUBSCRIPTION_ID
export OUTPUT=$ROOT_PATH/_output/$RESOURCE_GROUP
export AGENT_POOL="agentpool1"

echo "CLIENT_ID: $CLIENT_ID"
echo "NAME:$RESOURCE_GROUP"
echo "REGION:$REGION"
echo "TENANT_ID:$TENANT_ID"
echo "SUBSCRIPTION_ID:$TENANT_SUBSCRIPTION_ID"
echo "IDENTITY_SYSTEM:$IDENTITY_SYSTEM"
echo "NODE_COUNT:$NODE_COUNT"


cd $ROOT_PATH

if [ $IDENTITY_SYSTEM == "adfs" ] ; then
   
    KEY_LOCATION=$ROOT_PATH/spnauth.key
    CERT_LOCATION=$ROOT_PATH/spnauth.crt

    if [ ! -f $KEY_LOCATION ] ; then
        log_level -i "Private Key not found.Scale can not be performed"
    fi

    if [ ! -f $CERT_LOCATION ] ; then
        log_level -i "Certificate not found.Scale can not be performed"
    fi

    VAULT_ID=$(cat $ROOT_PATH/_output/$APIMODEL_FILE | jq '.properties.servicePrincipalProfile.keyvaultSecretRef.vaultID' | tr -d '"')
    SECRET_NAME=$(cat $ROOT_PATH/_output/$APIMODEL_FILE | jq '.properties.servicePrincipalProfile.keyvaultSecretRef.secretName' | tr -d '"')
    export VAULT_ID=$VAULT_ID
    export SECRET_NAME=$SECRET_NAME
    
    ./bin/aks-engine scale \
        --azure-env $AZURE_ENV \
        --subscription-id $SUBSCRIPTION_ID \
        --deployment-dir $OUTPUT \
        --location $REGION \
        --resource-group $RESOURCE_GROUP  \
        --master-FQDN $FQDN_ENDPOINT_SUFFIX \
        --node-pool $AGENT_POOL \
        --new-node-count $NODE_COUNT \
        --auth-method $AUTH_METHOD \
        --client-id $CLIENT_ID \
        --private-key-path $KEY_LOCATION \
        --certificate-path $CERT_LOCATION \
        --identity-system $IDENTITY_SYSTEM   || exit 1
else
    CLIENT_SECRET=$(cat $ROOT_PATH/_output/$APIMODEL_FILE | jq '.properties.servicePrincipalProfile.secret' | tr -d '"')
    export CLIENT_SECRET=$CLIENT_SECRET

    if [ $CLIENT_SECRET == "" ] ; then
        log_level -i "Client Secret not found.Scale can not be performed"
        exit 1
    fi
    
    ./bin/aks-engine scale \
        --azure-env $AZURE_ENV \
        --subscription-id $SUBSCRIPTION_ID \
        --deployment-dir $OUTPUT \
        --location $REGION \
        --resource-group $RESOURCE_GROUP  \
        --master-FQDN $FQDN_ENDPOINT_SUFFIX
        --node-pool $AGENT_POOL \
        --new-node-count $NODE_COUNT \
        --auth-method $AUTH_METHOD \
        --client-id $CLIENT_ID \
        --identity-system $IDENTITY_SYSTEM || exit 1

fi

log_level -i "Scaling of kubernetes cluster completed.Running E2E test..."

cd $ROOT_PATH
export CLUSTER_DEFINITION=_output/$APIMODEL_FILE
export CLEANUP_ON_EXIT=false
export NAME=$RESOURCE_GROUP
export CLIENT_ID=$CLIENT_ID
export TENANT_ID=$TENANT_ID
export SUBSCRIPTION_ID=$SUBSCRIPTION_ID
export TIMEOUT=20m
export LOCATION=$REGION
export API_PROFILE="2018-03-01-hybrid"

# Set the environment variables
export GOPATH=/home/azureuser
export GOROOT=/home/azureuser/bin/go
export PATH=$GOPATH:$GOROOT/bin:$PATH

set +e
make test-kubernetes > scale_test_results
set -e

RESULT=$?
log_level -i "Result: $RESULT"


if [ $RESULT -lt 3 ] ; then
    exit 0
else
    exit $RESULT
fi



