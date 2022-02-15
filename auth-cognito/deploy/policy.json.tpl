{  
  "Version": "2012-10-17",
  "Statement":[{
    "Effect": "Allow",
    "Action": [
     "dynamodb:BatchGetItem",
     "dynamodb:GetItem",
     "dynamodb:Query",
     "dynamodb:Scan",
     "dynamodb:BatchWriteItem",
     "dynamodb:PutItem",
     "dynamodb:DeleteItem",
     "dynamodb:UpdateItem"
    ],
    "Resource": "${dynamo_arn}"
   },
   {
    "Effect": "Allow",
    "Action": [
     "dynamodb:Query",
     "dynamodb:Scan",
     "dynamodb:BatchWriteItem"
    ],
    "Resource": "${dynamo_arn}/index/*"
   }
  ]
}