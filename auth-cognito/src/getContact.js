import AWS from 'aws-sdk';
import commonMiddleware from '../lib/commonMiddleware';
import createError from 'http-errors';

const dynamodb = new AWS.DynamoDB.DocumentClient();

async function getContactByName(name, email)
{
  let contact;
  console.log('name '+ name+ ' email: '+ email);
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

  if(!contact){
    throw new createError.NotFound(`Contact with name "${name}" not found`);
    }

    return contact;

}

async function getContact(event, context) {

  let name = event.queryStringParameters.name;
  
  if(typeof name === 'undefined'){
    let namePath = event.pathParameters.name;
    if(typeof namePath === 'undefined'){
      throw new createError.BadRequest('Name parameter not provided');
    }
    name=namePath;
  } 
  const {email} = event.requestContext.authorizer.claims;

  const contact = await getContactByName(name, email);
  return {
    statusCode: 200,
    body: JSON.stringify(contact),
  };
}

export const handler = commonMiddleware(getContact);


