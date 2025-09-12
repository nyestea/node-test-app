#!/bin/zsh

# copy part of source code from here
# https://code.amazon.com/packages/NeccoZshTools/blobs/mainline/--/configuration/bin/baseline-isengard-accounts

# isengard apis
# https://w.amazon.com/bin/view/AWS_IT_Security/Isengard/IsengardAPIPaginationEnforcement/

# duckhawk, codepipeline, codecommit, sabini
ACCOUNT_SEARCH_KEY_WORD="dux"
# ACCOUNT_SEARCH_KEY_WORD="ebs-server-snapshot-canary"

isengardcli list -A | grep $ACCOUNT_SEARCH_KEY_WORD | awk '{if ($2 == "♥") { print $3 } else { print $2 }}' > ./base_line_account_list
#isengardcli list | awk '{if ($2 == "♥") { print $3 } else { print $2 }}' > ./base_line_account_list


while read -r account; do 

echo "baseline account: $account"; 
isengardcli bl $account
echo "Done with baselining: ${account}"

done < ./base_line_account_list