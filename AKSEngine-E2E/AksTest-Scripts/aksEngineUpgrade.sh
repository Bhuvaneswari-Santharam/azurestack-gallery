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

        --upgrade-version)

            UPGRADE_VERISON="$2"

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

if [ -z "$UPGRADE_VERSION" ]

then

    echo ""

    echo "[ERR] --upgrade-verison is required"

    printUsage

fi



# Basic details of the system
log_level -i "Running  script as : $(whoami)"
log_level -i "System information: $(sudo uname -a)"


ROOT_PATH=/home/azureuser/src/github.com/Azure/aks-engine
cd $ROOT_PATH

log_level -i "Getting Resource group and region"

export RESOURCE_GROUP=`ls -dt1 _output/* | head -n 1 | cut -d/ -f2`
export REGION=`ls -dt1 _output/* | head -n 1 | cut -d/ -f2 | cut -d- -f2`

echo "REGION: $REGION"
echo "RESOURCE GROUP: $RESOURCE_GROUP"

if [ $RESOURCE_GROUP == "" ] ; then
    log_level -i "Resource group not found.Upgrade can not be performed"
    exit 1
fi

if [ $REGION == "" ] ; then
    log_level -i "Region not found.Upgrade can not be performed"
    exit 1
fi

APIMODEL_FILE=$RESOURCE_GROUP.json

cd $ROOT_PATH/_output

CLIENT_ID=$(cat $ROOT_PATH/_output/$APIMODEL_FILE | jq '.properties.servicePrincipalProfile.clientId'| tr -d '"')
FQDN_ENDPOINT_SUFFIX=$(cat $ROOT_PATH/_output/$APIMODEL_FILE | jq '.properties.customCloudProfile.environment.resourceManagerVMDNSSuffix' | tr -d '"')
IDENTITY_SYSTEM=$(cat $ROOT_PATH/_output/$APIMODEL_FILE | jq '.properties.customCloudProfile.identitySystem' | tr -d '"')
AUTH_METHOD=$(cat $ROOT_PATH/_output/$APIMODEL_FILE | jq '.properties.customCloudProfile.authenticationMethod' | tr -d '"')
AZURE_ENV_OLD=$(cat $ROOT_PATH/_output/$APIMODEL_FILE | jq '.properties.customCloudProfile.environment.name' | tr -d '"')

if [ $CLIENT_ID == "" ] ; then
    log_level -i "Client ID not found.Upgrade can not be performed"
    exit 1
fi

export CLIENT_ID=$CLIENT_ID
export CLIENT_SECRET=""
export NAME=$RESOURCE_GROUP
export REGION=$REGION
export TENANT_ID=$TENANT_ID
export SUBSCRIPTION_ID=$TENANT_SUBSCRIPTION_ID
export OUTPUT=$ROOT_PATH/_output/$RESOURCE_GROUP

echo "CLIENT_ID: $CLIENT_ID"
echo "NAME:$RESOURCE_GROUP"
echo "REGION:$REGION"
echo "TENANT_ID:$TENANT_ID"
echo "SUBSCRIPTION_ID:$TENANT_SUBSCRIPTION_ID"
echo "IDENTITY_SYSTEM:$IDENTITY_SYSTEM"
echo "NODE_COUNT:$NODE_COUNT"


cd $ROOT_PATH
sudo chown -R azureuser $ROOT_PATH/_output/$RESOURCE_GROUP

if [ $IDENTITY_SYSTEM == "adfs" ] ; then
   
    KEY_LOCATION=$ROOT_PATH/spnauth.key
    CERT_LOCATION=$ROOT_PATH/spnauth.crt

    ./bin/aks-engine upgrade \
        --subscription-id $SUBSCRIPTION_ID \
        --deployment-dir $OUTPUT \
        --location $REGION \
        --resource-group $RESOURCE_GROUP  \
        --auth-method $AUTH_METHOD \
        --client-id $CLIENT_ID \
        --private-key-path $KEY_LOCATION \
        --certificate-path $CERT_LOCATION \
        --upgrade-version $UPGRADE_VERISON \
        --force || exit 1
else
    CLIENT_SECRET=$(cat $ROOT_PATH/_output/$APIMODEL_FILE | jq '.properties.servicePrincipalProfile.secret' | tr -d '"')
    export CLIENT_SECRET=$CLIENT_SECRET

    if [ $CLIENT_SECRET == "" ] ; then
        log_level -i "Client Secret not found.Upgrade can not be performed"
        exit 1
    fi
    
    ./bin/aks-engine upgrade \
        --subscription-id $SUBSCRIPTION_ID \
        --deployment-dir $OUTPUT \
        --location $REGION \
        --resource-group $RESOURCE_GROUP  \
        --auth-method $AUTH_METHOD \
        --client-id $CLIENT_ID \
        --upgrade-version $UPGRADE_VERSION \
        --client-secret $CLIENT_SECRET
        --force || exit 1
fi

log_level -i "Upgrading kubernetes cluster to version $UPGRADE_VERSION completed.Running E2E test..."

cd $ROOT_PATH
export CLUSTER_DEFINITION=$AKSENGINE_APIMODEL
export CLEANUP_ON_EXIT=false
export NAME=$RESOURCE_GROUP
export CLIENT_ID=$CLIENT_ID
export TENANT_ID=$TENANT_ID
export SUBSCRIPTION_ID=$SUBSCRIPTION_ID
export TIMEOUT=20m
export REGION=$REGION

set +e
make test-kubernetes > upgrade_test_results
set -e

RESULT=$?
log_level -i "Result: $RESULT"

#Script returns exit=0 for the failure in the E2E test else throws the deployment error code
if [ $RESULT -lt 3 ] ; then
    exit 0
else
    exit $RESULT
fi



