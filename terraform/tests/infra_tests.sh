lambda_call() {
  aws lambda invoke --function-name Destruction-lambda-function out.txt
}
validate_efs_mount() {
  ssh -i ../node.pem ec2-user@$(cat ../publicIP.txt) mountpoint -q /wibble
}
test_validate_efs_mount() {
  fake mount 'echo $FAKE_PARAMS >/tmp/fake_params'


  assert_status_code 0 validate_efs_mount
}

test_lambda_is_accessible() {
  assert_status_code 0 lambda_call
}
