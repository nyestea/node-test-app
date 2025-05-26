export const handler = async (event) => {
  // TODO implement
  var nameParam = event.queryStringParameters.name;

  const response = {
    statusCode: 200,
    body: JSON.stringify('Hello' + nameParam + ' from Lambda!')
  };
  // just a comment
  return response;
};