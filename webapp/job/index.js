const qrate = require('qrate');
const axios = require('axios');
const express = require('express');
const bodyParser = require('body-parser')

const app = express();
let queue = [];

app.use(bodyParser.json());

const sendLog = qrate(async (_, done) => {
	if (queue.length > 0) {
		const payload = queue.slice(0, 5000);
		queue = queue.slice(5000);

		const res = await axios({
			method: 'post',
			url: '/send_bulk',
			baseURL: endpoint,
			data: JSON.stringify(payload),
			headers: {
				'Content-Type': 'application/json',
				'Authorization': `Bearer ${app_id}`,
			},
		});
		console.log(res.data);
	} else {
		console.log('skipped');
	}
	done();
}, 10, 20);

app.post('/send_log', (req, res) => {
	let payload = null;
	try {
		payload = JSON.parse(req.body.payload);
	} catch (e) {
		console.error('invalid json');
		return;
	}
	queue.push(payload)
	sendLog.push(req.body);
	res.send('queued');
});

app.listen(3000, () => {
	console.log('started');
});
