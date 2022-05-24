lambda_call() {
  aws lambda invoke --function-name lambda-cleanup-lambda-function out.txt
}
validate_efs_mount() {
  ssh -i ../ec2/node.pem ec2-user@$(cat ../ec2/publicIP.txt) mountpoint -q /wibble
}
test_validate_efs_mount() {
  assert_status_code 0 validate_efs_mount
}

test_lambda_is_accessible() {
  assert_status_code 0 lambda_call
}
