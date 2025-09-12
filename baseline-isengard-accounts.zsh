#!/usr/bin/env zsh

typeset -A ISENGARD_ENDPOINTS=(
  aws https://isengard-service.amazon.com
  aws-cn https://isengard-service.cn-north-1.amazonaws.com.cn
  # aws-us-gov https://isengard-service.pdt.aws-border.com
)

PRIMARY=attilany
SECONDARY=n
GROUP_OWNER=sabini-dev
typeset -a IAM_GROUP_OWNERS=(
  aws-support-e2m
)

PARTITION=aws

function usage() {
  print 'Usage: baseline-isengard-accounts [--partition PARTITION]'
  print
  print 'Available partitions:'
  print "  * ${(okj:\n  * :)ISENGARD_ENDPOINTS}"
}

function isengard() {
  local target="${1}" data="${2}"

  curl --silent --location --cookie ${HOME}/.midway/cookie --cookie-jar ${HOME}/.midway/cookie \
    --header 'Accept: */*' \
    --header 'Content-Type: application/json' \
    --header 'Content-Encoding: amz-1.0' \
    --header "X-Amz-Target: com.amazon.isengard.coral.IsengardService.${target}" \
    --data "${data}" ${ISENGARD_ENDPOINTS[${PARTITION}]} | jq '.'
}

function baseline() {
  local results="$(
    isengard ListOwnedAWSAccounts '{
      "MaxResults": 1000,
      "BaselineNeededOnly": true,
      "ProductionAccountsOnly": true
    }'
  )"

  local next=$(jq -r '.NextToken' <<< "${results}")
  local -a accounts=($(jq -r '.AWSAccountIDList[]' <<< "${results}"))

  while [[ ${next} != null ]]; do
    results="$(
      isengard ListOwnedAWSAccounts '{
        "MaxResults": 1000,
        "BaselineNeededOnly": true,
        "ProductionAccountsOnly": true,
        "NextToken": "'${next}'"
      }'
    )"

    next=$(jq -r '.NextToken' <<< "${results}")
    accounts+=($(jq -r '.AWSAccountIDList[]' <<< "${results}"))
  done

  print "Found ${#accounts} accounts to baseline"

  for account in ${accounts}; do
    local details="$(
      isengard GetAWSAccount '{
        "AWSAccountID": "'${account}'"
      }' | jq '.AWSAccount'
    )"

    local accountStatus=$(jq -r '.Status' <<< "${details}")

    if [[ ${accountStatus} != 'ACTIVE' ]]; then
      print "Skipping account ${account} because it is ${accountStatus}"
      continue
    fi

    local -a errors=()

    local owner=$(jq -r '.PrimaryOwner' <<< "${details}")
    local group=$(jq -r '.PosixGroupOwner' <<< "${details}")

    local secondary="$(
      isengard ListSecondaryOwners '{
        "AWSAccountID": "'${account}'"
      }' | jq -r '.SecondaryOwnerList | join(", ")'
    )"

    if [[ ${owner} != ${PRIMARY} ]]; then
      #errors+="Owner [${owner}] is not [${PRIMARY}]"
      print "Skipping account ${account} because ${PRIMARY} is NOT a primary owner."
      continue
    fi

    # if [[ ${secondary} != ${SECONDARY} ]]; then
    #   errors+="Secondary Owner [${secondary}] is not [${SECONDARY}]"
    # fi

    # if [[ ${group} != ${GROUP_OWNER} ]]; then
    #   errors+="Group Owner [${group}] is not [${GROUP_OWNER}]"
    # fi

    # local roles="$(
    #   isengard ListIAMRolesWithPermissionsAndClassification '{
    #     "AWSAccountID": "'${account}'"
    #   }' | jq '.IAMRoleList[]'
    # )"

    # for name in $(jq -r '.IAMRoleName' <<< "${roles}"); do
    #   for group in $(jq -r 'select(.IAMRoleName == "'${name}'").GroupPermissionList[].Group' <<< "${roles}"); do
    #     if (( ${IAM_GROUP_OWNERS[(ie)${group}]} > ${#IAM_GROUP_OWNERS} )); then
    #       errors+="IAM Role [${name}] has invalid owner [${group}]"
    #     fi
    #   done
    # done

    if ! (( #errors )); then
      isengard BaselineAWSAccount '{
        "AWSAccountID": "'${account}'",
        "BaselineType": {
          "AccountBaseline": true
        }
      }' &> /dev/null

      print "Baselined account: ${account}"
    else
      print "Found errors baselining account ${account}"
      print "  * ${(j:\n  * :)errors}"
    fi
  done
}

typeset -a help
typeset -A partition=(--partition aws)
zparseopts -E -K -- h=help -help=help p:=partition -partition:=partition 2>/dev/null

if (( #help )); then
  usage
  exit
fi

PARTITION=${(v)partition:l}

if (( ${${(@k)ISENGARD_ENDPOINTS}[(ie)${PARTITION}]} > ${#${(@k)ISENGARD_ENDPOINTS}} )); then
  raise "Unknown partition: ${PARTITION}"
fi

if [[ ${PARTITION} = 'aws-cn' ]]; then
  IAM_GROUP_OWNERS+=(
    operatornet-isengard-nwcd-cs
    operatornet-isengard-nwcd-es
    operatornet-isengard-nwcd-ps
  )
fi

baseline