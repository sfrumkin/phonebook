import AWS from 'aws-sdk';
import commonMiddleware from '../lib/commonMiddleware';
import createError from 'http-errors';

const dynamodb = new AWS.DynamoDB.DocumentClient();

async function deleteContactByName(name, email)
{
  let contact;
  console.log('name '+ name+ ' email: '+ email);
  //first get the contact
  try{
    const result = await dynamodb.get({
      TableName: process.env.CONTACTS_TABLE_NAME,
      Key: { pk: 'CONTACT_'+name, sk: 'ACCOUNT_' + email },
    }).promise();

    contact= result.Item;
    
  } catch(error){
    console.error(error);
    throw new createError.InternalServerError(error);
  }
  if(!contact) throw new createError.NotFound("no such item");
  
  //then delete the contact
  try{
    const result = await dynamodb.delete({
      TableName: process.env.CONTACTS_TABLE_NAME,
      Key: { pk: 'CONTACT_'+name, sk: 'ACCOUNT_' + email },
    }).promise();

  } catch(error){
    console.error(error);
    throw new createError.InternalServerError(error);
  }

    return;

}

async function deleteContact(event, context) {

  let name = event.queryStringParameters.name;
  
  if(typeof name === 'undefined'){
    let namePath = event.pathParameters.name;
    if(typeof namePath === 'undefined'){
      throw new createError.BadRequest('Name parameter not provided');
    }
    name=namePath;
  } 
  const {email} = event.requestContext.authorizer.claims;

  await deleteContactByName(name, email);
  return {
    statusCode: 200,
    body: JSON.stringify({}),
  };
}

export const handler = commonMiddleware(deleteContact);


