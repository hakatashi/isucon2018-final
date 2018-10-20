const qrate = require('qrate');
const axios = require('axios');
const express = require('express');
const bodyParser = require('body-parser')

const app = express();

app.use(bodyParser.json());

const sendLog = qrate(async ({endpoint, app_id, payload}, done) => {
	console.log({endpoint, app_id, payload});
	const res = await axios({
		method: 'post',
		url: '/send',
		baseURL: endpoint,
		data: payload,
		headers: {
			'Content-Type': 'application/json',
			'Authorization': `Bearer ${app_id}`,
		},
	});
	console.log(res);
	done();
}, 10, 20);

app.post('/send_log', (req, res) => {
	sendLog.push(req.body);
	res.send('queued');
});

app.listen(3000, () => {
	console.log('started');
});
