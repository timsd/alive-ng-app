import https from 'https';

const token = process.env.GLITCHTIP_TOKEN || 'ed1c7fb0f953bd2065d7af2f84f69c5b647cb94ea15b0daa8206eda5f688c66f';

function get(path) {
  return new Promise((resolve, reject) => {
    const req = https.request({
      hostname: 'glitchtip.alivenigeria.org',
      port: 443,
      path: path,
      method: 'GET',
      headers: {
        'Authorization': 'Bearer ' + token,
        'Content-Type': 'application/json'
      }
    }, res => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          resolve({ status: res.statusCode, data: JSON.parse(data) });
        } catch (e) {
          resolve({ status: res.statusCode, data });
        }
      });
    });
    req.on('error', reject);
    req.end();
  });
}

const targetIssueIds = [224, 223, 222, 221, 218, 216, 215, 212, 210, 208, 204, 203, 202, 201, 226, 172];

async function inspectIssues() {
  for (const id of targetIssueIds) {
    const res = await get(`/api/0/issues/${id}/events/latest/`);
    console.log(`\n======================================================`);
    console.log(`ISSUE #${id} (Status: ${res.status})`);
    if (res.status === 200 && res.data) {
      const evt = res.data;
      console.log(`Title: ${evt.title}`);
      console.log(`Message: ${evt.message || ''}`);
      console.log(`Platform: ${evt.platform} | Release: ${evt.release} | Environment: ${evt.environment}`);
      console.log(`Date Created: ${evt.dateCreated}`);
      if (evt.tags) {
        console.log(`Tags:`, evt.tags.map(t => `${t.key}=${t.value}`).join(', '));
      }
      
      // Look for stack trace or exception entries
      if (evt.entries) {
        for (const entry of evt.entries) {
          if (entry.type === 'exception') {
            for (const val of entry.data.values || []) {
              console.log(`\nEXCEPTION TYPE: ${val.type}`);
              console.log(`EXCEPTION VALUE: ${val.value}`);
              if (val.stacktrace && val.stacktrace.frames) {
                console.log(`STACK TRACE (top 10 frames):`);
                const frames = val.stacktrace.frames.slice(-10);
                for (const f of frames) {
                  console.log(`  at ${f.function || 'unknown'} (${f.filename || f.module}:${f.lineNo}:${f.colNo})`);
                }
              }
            }
          } else if (entry.type === 'breadcrumbs') {
            console.log(`\nLAST 5 BREADCRUMBS:`);
            const crumbs = (entry.data.values || []).slice(-5);
            for (const c of crumbs) {
              console.log(`  [${c.category || 'crumb'}] ${c.message || JSON.stringify(c.data)}`);
            }
          }
        }
      }
    } else {
      console.log(`Error fetching event for #${id}:`, res.data);
    }
  }
}

inspectIssues().catch(console.error);

