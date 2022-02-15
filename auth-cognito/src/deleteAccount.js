global.fetch = require('node-fetch');
const AmazonCognitoIdentity = require('amazon-cognito-identity-js-with-node-fetch');
const CognitoUserPool = AmazonCognitoIdentity.CognitoUserPool;
const AWS = require('aws-sdk');
const request = require('request');
const jwkToPem = require('jwk-to-pem');
const jwt = require('jsonwebtoken');
import commonMiddleware from '../lib/commonMiddleware';
import createError from 'http-errors';

const poolData = {    
  UserPoolId : process.env.COGNITO_USER_POOL_ID, // Your user pool id here    
  ClientId : process.env.COGNITO_POOL_CLIENT_ID // Your client id here
  }; 
const pool_region = process.env.REGION;

const userPool = new AmazonCognitoIdentity.CognitoUserPool(poolData);

const dynamodb = new AWS.DynamoDB.DocumentClient();

var cognitoUser;

async function deleteAccount(event, context) {

  const {password, username} = event.body;
  const {email} = event.requestContext.authorizer.claims;
  try{
    await LoginUser(username, password);
    console.log("After first login user: " + username);
    await Delete();
    console.log("After delete user: " + username);
  }
  catch (err)
  {
    console.log(err);
    return {
      statusCode: 501,
      body: JSON.stringify({})
    };
  }

  const params = {
    TableName: process.env.CONTACTS_TABLE_NAME,
    IndexName: 'SkIndex',
    KeyConditionExpression: 'sk = :sk' ,
    ExpressionAttributeValues: {
      ':sk':  'ACCOUNT_' + email,
    },
  };

  let items;
  try{
    const result = await dynamodb.query(params).promise();
    console.log('after querying contacts of account');
    items = result.Items;
    await dynamodb.delete({
      TableName: process.env.CONTACTS_TABLE_NAME,
      Key: { pk: 'ACCOUNT_' + email, sk: username },
    }).promise();
    console.log('after deleting account');
  } catch(error){
    console.error(error);
    throw new createError.InternalServerError(error);
  } 

  
  let leftItems = items.length;
  let group = [];
  let groupNumber = 0;

  console.log('Total items to be deleted', leftItems);

  for (const i of items) {
      const deleteReq = {
          DeleteRequest: {
              Key: {
                  sk: i.sk,
                  pk: i.pk
              },
          },
      };

      group.push(deleteReq);
      leftItems--;

      if (group.length === 25 || leftItems < 1) {
          groupNumber++;

          console.log(`Batch ${groupNumber} to be deleted.`);

          const params = {
              RequestItems: {
                  [process.env.CONTACTS_TABLE_NAME]: group,
              },
          };
          try{
            await dynamodb.batchWrite(params).promise();
          } catch(error){
            console.error(error);
            throw new createError.InternalServerError(error);
          } 
      
          console.log(
              `Batch ${groupNumber} processed. Left items: ${leftItems}`
          );

          // reset
          group = [];
      }
  }

  return {
    statusCode: 200,
    body: JSON.stringify({})
  };

}

function LoginUser(username, password) {
  var authenticationDetails = new AmazonCognitoIdentity.AuthenticationDetails({
      Username : username,
      Password : password,
  });

  var userData = {
      Username : username,
      Pool : userPool
  };
  cognitoUser = new AmazonCognitoIdentity.CognitoUser(userData);
  console.log('In login: '+ userData.Username + ' ' + userData.Pool)
  return new Promise((resolve, reject) => (
    cognitoUser.authenticateUser(authenticationDetails, {
      onSuccess: function (result) {
          console.log('success');
          resolve();
      },
      onFailure: function(err) {
          console.log(err);
          reject(err);
      },

    })
  ));
}

function Delete()
{
  return new Promise((resolve, reject) => (
    cognitoUser.deleteUser( (err, result) => {
      if (err) {
        console.log('Could not delete user');
        console.log(err);
        reject(err);
      } else {
        console.log('Deleted user');
        resolve(result);
      }
    })
  ));
}

export const handler = commonMiddleware(deleteAccount);