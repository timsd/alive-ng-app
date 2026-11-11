import https from 'https';
import fs from 'fs';

const token = process.env.GLITCHTIP_TOKEN || 'ed1c7fb0f953bd2065d7af2f84f69c5b647cb94ea15b0daa8206eda5f688c66f';

function get(urlOrPath) {
  return new Promise((resolve, reject) => {
    const isFullUrl = urlOrPath.startsWith('http');
    const url = isFullUrl ? new URL(urlOrPath) : new URL(urlOrPath, 'https://glitchtip.alivenigeria.org');
    
    const req = https.request({
      hostname: url.hostname,
      port: 443,
      path: url.pathname + url.search,
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
          resolve({ status: res.statusCode, headers: res.headers, data: JSON.parse(data) });
        } catch (e) {
          resolve({ status: res.statusCode, headers: res.headers, data });
        }
      });
    });
    req.on('error', reject);
    req.end();
  });
}

// Parse Sentry/GlitchTip pagination Link header
function parseLinkHeader(header) {
  if (!header) return {};
  const links = {};
  const parts = header.split(',');
  for (const part of parts) {
    const match = part.match(/<([^>]+)>;\s*rel="([^"]+)"(?:;\s*results="([^"]+)")?/);
    if (match) {
      const [, url, rel, results] = match;
      links[rel] = { url, hasMore: results === 'true' };
    }
  }
  return links;
}

async function fetchAllIssues() {
  let nextUrl = '/api/0/projects/aliveng/aliveapp/issues/?limit=100';
  const allIssues = [];

  while (nextUrl) {
    console.log(`Fetching: ${nextUrl}...`);
    const res = await get(nextUrl);
    if (res.status !== 200 || !Array.isArray(res.data)) {
      console.error(`Error ${res.status}:`, res.data);
      break;
    }
    allIssues.push(...res.data);
    
    const links = parseLinkHeader(res.headers.link);
    if (links.next && links.next.hasMore && links.next.url !== nextUrl) {
      nextUrl = links.next.url;
    } else {
      nextUrl = null;
    }
  }

  console.log(`\nTotal issues fetched: ${allIssues.length}`);
  
  // Save all issues to JSON for analysis
  fs.writeFileSync('scripts/glitchtip_issues.json', JSON.stringify(allIssues, null, 2));

  // Print grouped summary
  const statusGroups = {};
  for (const issue of allIssues) {
    const st = issue.status || 'unknown';
    statusGroups[st] = (statusGroups[st] || 0) + 1;
  }
  console.log('\nStatus breakdown:', statusGroups);

  console.log('\nTop 25 Issues by Event Count:');
  const sorted = [...allIssues].sort((a, b) => (parseInt(b.count) || 0) - (parseInt(a.count) || 0));
  for (let i = 0; i < Math.min(25, sorted.length); i++) {
    const iss = sorted[i];
    console.log(`[#${i + 1}] ID: ${iss.id} | Events: ${iss.count} | Users: ${iss.userCount || 0} | Status: ${iss.status}`);
    console.log(`    Title: ${iss.title}`);
    console.log(`    Culprit: ${iss.culprit}`);
    console.log(`    Last Seen: ${iss.lastSeen}\n`);
  }
}

fetchAllIssues().catch(console.error);

