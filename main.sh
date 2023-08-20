json_dict() {
    declare key value in_value="${!1}"
    unset "$2"
    declare -g -A "$2"
    declare -n hash_table="$2"
    while IFS= read -r -d '' key && IFS= read -r -d '' value; do
        hash_table[$key]=$value
    done < <(
        jq -cjn --argjson d "$in_value" \
            '$d | to_entries[] | ( .key, "\u0000", .value, "\u0000")'
    )
}
ZIPS=$(find . -name "lambdaFunction*.zip")
for zipFile in $ZIPS; do
    tmp=${zipFile#*./lambdaFunction}
    functionName=${tmp%.zip*}
    arr=$(cat "$functionName.txt")
    json_dict arr generalData
    declare -p generalData
    TAGS_STR=${generalData[tags]}
    json_dict TAGS_STR tags
    declare -p tags
    ROLE=${generalData[role]}
    DESCRIPTION=${generalData[description]}
    API_GATEWAY=${tags[apigw]}
    TAGGG=${generalData[tagstring]}
    CRITICALITY=${tags[criticality]}
    ACTOR=${tags[actor]}
    ACCESSIBILITY=${tags[accessibility]}
    TYPE=${tags[type]}
    SERVICE=${tags[service]}
    NEED_AUTHENTICATION=${generalData[needAuthentication]}
    CACHEABLE=${generalData[cacheable]}
    STAGE=${generalData[stage]}
    TEAM=${tags[team]}
    LAYERS=${generalData[layers]}
    ENVS=${generalData[envs]}
    METHOD=${generalData[method]}
    API_GATEWAY_ID=${generalData[apigateway]}
    CLUSTER_DATABASE="$1"
    DATABASE_URL="$2"
    PASSWORD_DATABASE="$3"
    USERNAME_DATABASE="$4"
    ROOM_TABLE_WS="$5"
    WS_URL="$6"
    AUTHORIZER_ID="$7"
    echo ">    Intentando eliminar función desactualizada"
    aws lambda get-function --function-name "$functionName" && aws lambda delete-function --function-name "$functionName" || echo ">    No se encontró la función con $functionName"
    echo ">    -Intentando eliminar función desactualizada-"

    arnFunction=$(aws lambda get-function --function-name "$functionName-$STAGE" | jq .Configuration | jq .FunctionArn | sed 's/"//g')

    echo ">    Role: $ROLE"

    if [ -z "$arnFunction" ]; then
        echo ">    There is not a function, so it will be created"
        echo ">    Creating function $functionName-$STAGE"
        arnFunction=$(aws lambda create-function --function-name "$functionName-$STAGE" --runtime python3.8 --zip-file fileb://$zipFile --handler lambda_function.lambdaHandler --role "$ROLE" --description "$DESCRIPTION" --layers $LAYERS --environment Variables={"CLUSTER_DATABASE='$CLUSTER_DATABASE',DATABASE_URL='$DATABASE_URL',PASSWORD_DATABASE='$PASSWORD_DATABASE',USERNAME_DATABASE='$USERNAME_DATABASE',ROOM_TABLE_WS='$ROOM_TABLE_WS',WS_URL='$WS_URL'$ENVS"} | jq .FunctionArn | sed 's/"//g')
        echo ">    Function created $arnFunction"
        aws lambda wait function-exists --function-name "$arnFunction"
    else
        echo ">    Existe una función, por lo que se actualizará el código"
        aws lambda update-function-code --function-name "$functionName-$STAGE" --zip-file fileb://"$zipFile" &&
            aws lambda wait function-updated-v2 --function-name "$arnFunction" &&
            aws lambda update-function-configuration --function-name "$arnFunction" --role "$ROLE" --description "$DESCRIPTION" --layers $LAYERS --environment Variables={"CLUSTER_DATABASE='$CLUSTER_DATABASE',DATABASE_URL='$DATABASE_URL',PASSWORD_DATABASE='$PASSWORD_DATABASE',USERNAME_DATABASE='$USERNAME_DATABASE',ROOM_TABLE_WS='$ROOM_TABLE_WS',WS_URL='$WS_URL'$ENVS"}
    fi
    aws lambda wait function-active --function-name "$arnFunction" &&
        aws lambda wait function-active-v2 --function-name "$arnFunction"

    ROUTE=${generalData[route]}
    echo ">    Tags $TAGGG"
    aws lambda tag-resource --resource "$arnFunction" --tags "$TAGGG"
    [ "$NEED_AUTHENTICATION" = "true" ] && [ "$AUTHORIZER_ID" ] && AUTH_STR=" --authorization-type JWT --authorizer-id $AUTHORIZER_ID "
    echo ">    Configurando ruta para el caso de uso $functionName..."
    INTEGRATION_OBTAINED=$(aws apigatewayv2 get-routes --api-id "$API_GATEWAY_ID" | jq -c '.Items[] | select(.RouteKey=="'"$METHOD $ROUTE"'") | .Target' | sed 's/integrations\///g' | sed 's/"//g')
    
    if [ -z "$ROUTE" ]; then
        echo ">    No hay ruta, por lo que no se intentará buscar ninguna integración"
    else
        if [ -z "$INTEGRATION_OBTAINED" ]; then
            echo ">    No se obtuvo ninguna integración o ruta creada previamente, se crearán las respectivas"
            INTEGRATION_ID=$(aws apigatewayv2 create-integration --api-id "$API_GATEWAY_ID" --integration-uri "$arnFunction" --integration-type AWS_PROXY --payload-format-version 2.0 | jq .IntegrationId | sed 's/"//g') &&
                echo ">    INTEGRATION_ID : $INTEGRATION_ID" &&
                ROUTE_ID=$(aws apigatewayv2 create-route --api-id $API_GATEWAY_ID --route-key "$METHOD $ROUTE" --target integrations/$INTEGRATION_ID $AUTH_STR) &&
                echo ">    ROUTE_ID $ROUTE_ID"
            aws lambda add-permission --statement-id api-invoke-lambda --action lambda:InvokeFunction --function-name "$arnFunction" --principal apigateway.amazonaws.com --source-arn "arn:aws:execute-api:us-east-1:$AWS_ACCOUNT_ID:$API_GATEWAY_ID/*"
            aws lambda wait function-updated-v2 --function-name "$arnFunction"
        else
            echo ">    Ya había una ruta creada se cambiará la función"
            INTEGRATION_ID=$(aws apigatewayv2 update-integration --api-id "$API_GATEWAY_ID" --integration-uri "$arnFunction" --integration-id "$INTEGRATION_OBTAINED")
        fi
    fi
done
