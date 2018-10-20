const fs = require('fs');
const {promisify} = require('util');
const day = require('dayjs');

(async () => {
	const data = await promisify(fs.readFile)('isucoin.txt');
	const records = data.toString().trim().split('\r\n').slice(1);

	const by_s = new Map();
	const by_m = new Map();
	const by_h = new Map();
	const recordMap = new Map();

	for (const record of records) {
		const [rawId, amount, rawPrice, date] = record.split('\t');
		const id = parseInt(rawId);
		const price = parseInt(rawPrice);
		const time = day(date.replace(' ', 'T') + 'Z');

		recordMap.set(id, record);

		const s = time.format('YYYY-MM-DD HH:mm:ss');
		const m = time.format('YYYY-MM-DD HH:mm:00');
		const h = time.format('YYYY-MM-DD HH:00:00');

		by_s.set(s, {
			high: by_s.get(s) ? Math.max(by_s.get(s).high, price) : price,
			low: by_s.get(s) ? Math.min(by_s.get(s).low, price) : price,
			openId: by_s.get(s) ? Math.min(by_s.get(s).openId, id) : id,
			closeId: by_s.get(s) ? Math.max(by_s.get(s).closeId, id) : id,
		});

		by_m.set(m, {
			high: by_m.get(m) ? Math.max(by_m.get(m).high, price) : price,
			low: by_m.get(m) ? Math.min(by_m.get(m).low, price) : price,
			openId: by_m.get(m) ? Math.min(by_m.get(m).openId, id) : id,
			closeId: by_m.get(m) ? Math.max(by_m.get(m).closeId, id) : id,
		});

		by_h.set(h, {
			high: by_h.get(h) ? Math.max(by_h.get(h).high, price) : price,
			low: by_h.get(h) ? Math.min(by_h.get(h).low, price) : price,
			openId: by_h.get(h) ? Math.min(by_h.get(h).openId, id) : id,
			closeId: by_h.get(h) ? Math.max(by_h.get(h).closeId, id) : id,
		});
	}

	const value_s = [];

	for (const [date, {high, low, openId, closeId}] of by_s.entries()) {
		value_s.push(`(STR_TO_DATE('${date}', '%Y-%m-%d %H:%i:%s'), ${high}, ${low}, ${recordMap.get(openId).split('\t')[2]}, ${recordMap.get(closeId).split('\t')[2]})`);
	}

	const query_s = `INSERT INTO candle_by_s (\`date\`, high, low, open, close) VALUES ${value_s.join(',')};`;
	await promisify(fs.writeFile)('candle_by_s.sql', query_s);

	const value_m = [];

	for (const [date, {high, low, openId, closeId}] of by_m.entries()) {
		value_m.push(`(STR_TO_DATE('${date}', '%Y-%m-%d %H:%i:%s'), ${high}, ${low}, ${recordMap.get(openId).split('\t')[2]}, ${recordMap.get(closeId).split('\t')[2]})`);
	}

	const query_m = `INSERT INTO candle_by_s (\`date\`, high, low, open, close) VALUES ${value_m.join(',')};`;
	await promisify(fs.writeFile)('candle_by_m.sql', query_m);

	const value_h = [];

	for (const [date, {high, low, openId, closeId}] of by_h.entries()) {
		console.log(openId, closeId);
		value_h.push(`(STR_TO_DATE('${date}', '%Y-%m-%d %H:%i:%s'), ${high}, ${low}, ${recordMap.get(openId).split('\t')[2]}, ${recordMap.get(closeId).split('\t')[2]})`);
	}

	const query_h = `INSERT INTO candle_by_s (\`date\`, high, low, open, close) VALUES ${value_h.join(',')};`;
	await promisify(fs.writeFile)('candle_by_h.sql', query_h);
})();