// Loads in the AWS SDK
const AWS = require('aws-sdk');

// Creates the document client specifing the region 
const ddb = new AWS.DynamoDB.DocumentClient({ region: 'us-east-1' });

var params = {
    TableName: "Student",

};

async function listItems() {
    try {
        const data = await ddb.scan(params).promise()
        return data
    } catch (err) {
        return err
    }
}

exports.handler = async (event, context, callback) => {
    try {
        const data = await listItems();
        console.log(data);
        return {
            statusCode: 200,
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                message: data,
            }),
        }
    } catch (err) {
        return console.error(err)
    }
};
