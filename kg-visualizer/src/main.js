import * as d3 from 'd3';

// API base URL - direct connection to API server
const API_BASE = 'https://8080--019c11f7-ac99-7331-aaf5-d160ef109e39.eu-central-1-01.gitpod.dev';

// State
let graphData = { nodes: [], links: [] };
let simulation = null;
let svg, linkGroup, linkLabelGroup, nodeGroup;

// Initialize
document.addEventListener('DOMContentLoaded', () => {
  initSVG();
  bindEvents();
  loadGraph();
});

function initSVG() {
  const width = window.innerWidth;
  const height = window.innerHeight;
  
  svg = d3.select('#graph')
    .attr('width', width)
    .attr('height', height);
  
  // Create groups for layering
  linkGroup = svg.append('g').attr('class', 'links');
  linkLabelGroup = svg.append('g').attr('class', 'link-labels');
  nodeGroup = svg.append('g').attr('class', 'nodes');
  
  // Click on background to clear selection
  svg.on('click', (event) => {
    if (event.target.tagName === 'svg') {
      clearHighlight();
      hideTooltip();
    }
  });
  
  // Handle resize
  window.addEventListener('resize', () => {
    svg.attr('width', window.innerWidth).attr('height', window.innerHeight);
    if (simulation) {
      simulation.force('center', d3.forceCenter(window.innerWidth / 2, window.innerHeight / 2));
      simulation.alpha(0.3).restart();
    }
  });
}

function bindEvents() {
  // Add triple
  document.getElementById('addBtn').addEventListener('click', addTriple);
  
  // Clear graph
  document.getElementById('clearBtn').addEventListener('click', () => {
    if (confirm('Clear all data?')) {
      fetch(`${API_BASE}/api/clear`, { method: 'POST' })
        .then(() => loadGraph())
        .catch(err => alert('Error: ' + err.message));
    }
  });
  
  // Refresh
  document.getElementById('refreshBtn').addEventListener('click', loadGraph);
  
  // Find path
  document.getElementById('findPathBtn').addEventListener('click', findPath);
  
  // Example buttons
  document.querySelectorAll('.example-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      const from = btn.dataset.from;
      const to = btn.dataset.to;
      document.getElementById('fromEntity').value = from;
      document.getElementById('toEntity').value = to;
      findPath();
    });
  });
  
  // Enter key support
  ['subject', 'predicate', 'object'].forEach(id => {
    document.getElementById(id).addEventListener('keypress', (e) => {
      if (e.key === 'Enter') addTriple();
    });
  });
  
  ['fromEntity', 'toEntity'].forEach(id => {
    document.getElementById(id).addEventListener('keypress', (e) => {
      if (e.key === 'Enter') findPath();
    });
  });
}

async function loadGraph() {
  try {
    const [graphRes, statsRes] = await Promise.all([
      fetch(`${API_BASE}/api/graph`),
      fetch(`${API_BASE}/api/stats`)
    ]);
    
    const graph = await graphRes.json();
    const stats = await statsRes.json();
    
    // Update stats
    document.getElementById('stats').innerHTML = `
      <b>Entities:</b> ${stats.entities}<br>
      <b>Relations:</b> ${stats.relations}<br>
      <b>Triples:</b> ${stats.triples}
    `;
    
    graphData = graph;
    renderGraph();
    hideTooltip();
    
  } catch (err) {
    document.getElementById('stats').innerHTML = `<span style="color:#ff6b6b">Error: ${err.message}</span>`;
    console.error('Failed to load graph:', err);
  }
}

function renderGraph() {
  const width = window.innerWidth;
  const height = window.innerHeight;
  
  // Clear previous
  linkGroup.selectAll('*').remove();
  linkLabelGroup.selectAll('*').remove();
  nodeGroup.selectAll('*').remove();
  
  if (graphData.nodes.length === 0) return;
  
  // Create simulation
  simulation = d3.forceSimulation(graphData.nodes)
    .force('link', d3.forceLink(graphData.links).id(d => d.id).distance(150))
    .force('charge', d3.forceManyBody().strength(-500))
    .force('center', d3.forceCenter(width / 2, height / 2))
    .force('collision', d3.forceCollide().radius(50));
  
  // Draw links
  const links = linkGroup.selectAll('line')
    .data(graphData.links)
    .enter()
    .append('line')
    .attr('class', 'link');
  
  // Draw link labels
  const linkLabels = linkLabelGroup.selectAll('text')
    .data(graphData.links)
    .enter()
    .append('text')
    .attr('class', 'link-label')
    .text(d => d.label);
  
  // Draw nodes
  const nodes = nodeGroup.selectAll('g')
    .data(graphData.nodes)
    .enter()
    .append('g')
    .attr('class', d => `node ${d.group === 2 ? 'value' : 'entity'}`)
    .call(d3.drag()
      .on('start', dragStarted)
      .on('drag', dragged)
      .on('end', dragEnded))
    .on('click', (event, d) => {
      event.stopPropagation();
      highlightConnections(d.id);
    });
  
  nodes.append('circle')
    .attr('r', 22);
  
  nodes.append('text')
    .attr('dy', 40)
    .attr('text-anchor', 'middle')
    .text(d => d.id);
  
  // Update positions on tick
  simulation.on('tick', () => {
    links
      .attr('x1', d => d.source.x)
      .attr('y1', d => d.source.y)
      .attr('x2', d => d.target.x)
      .attr('y2', d => d.target.y);
    
    linkLabels
      .attr('x', d => (d.source.x + d.target.x) / 2)
      .attr('y', d => (d.source.y + d.target.y) / 2);
    
    nodes.attr('transform', d => `translate(${d.x},${d.y})`);
  });
}

function dragStarted(event) {
  if (!event.active) simulation.alphaTarget(0.3).restart();
  event.subject.fx = event.subject.x;
  event.subject.fy = event.subject.y;
}

function dragged(event) {
  event.subject.fx = event.x;
  event.subject.fy = event.y;
}

function dragEnded(event) {
  if (!event.active) simulation.alphaTarget(0);
  event.subject.fx = null;
  event.subject.fy = null;
}

function highlightConnections(nodeId) {
  clearHighlight();
  
  const connected = new Set([nodeId]);
  const connectedLinkIndices = [];
  
  graphData.links.forEach((link, i) => {
    const src = typeof link.source === 'object' ? link.source.id : link.source;
    const tgt = typeof link.target === 'object' ? link.target.id : link.target;
    
    if (src === nodeId || tgt === nodeId) {
      connected.add(src);
      connected.add(tgt);
      connectedLinkIndices.push(i);
    }
  });
  
  // Highlight nodes
  nodeGroup.selectAll('.node')
    .classed('highlighted', d => d.id === nodeId)
    .classed('dimmed', d => !connected.has(d.id));
  
  // Highlight links
  linkGroup.selectAll('line')
    .classed('highlighted', (d, i) => connectedLinkIndices.includes(i))
    .classed('dimmed', (d, i) => !connectedLinkIndices.includes(i));
  
  linkLabelGroup.selectAll('text')
    .classed('highlighted', (d, i) => connectedLinkIndices.includes(i))
    .classed('dimmed', (d, i) => !connectedLinkIndices.includes(i));
  
  // Show tooltip
  const outgoing = [];
  const incoming = [];
  
  graphData.links.forEach(link => {
    const src = typeof link.source === 'object' ? link.source.id : link.source;
    const tgt = typeof link.target === 'object' ? link.target.id : link.target;
    
    if (src === nodeId) outgoing.push(`${link.label} → ${tgt}`);
    if (tgt === nodeId) incoming.push(`${src} → ${link.label}`);
  });
  
  let info = '';
  if (outgoing.length) info += `Out: ${outgoing.join(', ')}`;
  if (incoming.length) info += (info ? '<br>' : '') + `In: ${incoming.join(', ')}`;
  
  showTooltip(nodeId, info || 'No connections');
}

function clearHighlight() {
  nodeGroup.selectAll('.node')
    .classed('highlighted', false)
    .classed('dimmed', false);
  
  linkGroup.selectAll('line')
    .classed('highlighted', false)
    .classed('dimmed', false);
  
  linkLabelGroup.selectAll('text')
    .classed('highlighted', false)
    .classed('dimmed', false);
}

async function findPath() {
  const from = document.getElementById('fromEntity').value.trim();
  const to = document.getElementById('toEntity').value.trim();
  
  if (!from || !to) {
    alert('Please enter both From and To entities');
    return;
  }
  
  try {
    const res = await fetch(`${API_BASE}/api/reason?from=${encodeURIComponent(from)}&to=${encodeURIComponent(to)}`);
    const data = await res.json();
    
    if (!data.found) {
      showTooltip('No path found', `Cannot reach "${to}" from "${from}"`);
      clearHighlight();
      return;
    }
    
    // Collect path nodes and links
    const pathNodes = new Set([from]);
    const pathLinkIndices = [];
    
    data.path.forEach(step => {
      pathNodes.add(step.entity);
      pathNodes.add(step.next);
    });
    
    graphData.links.forEach((link, i) => {
      const src = typeof link.source === 'object' ? link.source.id : link.source;
      const tgt = typeof link.target === 'object' ? link.target.id : link.target;
      
      data.path.forEach(step => {
        if (src === step.entity && tgt === step.next) {
          pathLinkIndices.push(i);
        }
      });
    });
    
    // Highlight
    clearHighlight();
    
    nodeGroup.selectAll('.node')
      .classed('highlighted', d => pathNodes.has(d.id))
      .classed('dimmed', d => !pathNodes.has(d.id));
    
    linkGroup.selectAll('line')
      .classed('highlighted', (d, i) => pathLinkIndices.includes(i))
      .classed('dimmed', (d, i) => !pathLinkIndices.includes(i));
    
    linkLabelGroup.selectAll('text')
      .classed('highlighted', (d, i) => pathLinkIndices.includes(i))
      .classed('dimmed', (d, i) => !pathLinkIndices.includes(i));
    
    showTooltip(`Path found (${data.hops} hops)`, data.conclusion);
    
  } catch (err) {
    alert('Error: ' + err.message);
    console.error('Find path error:', err);
  }
}

async function addTriple() {
  const subject = document.getElementById('subject').value.trim();
  const predicate = document.getElementById('predicate').value.trim();
  const object = document.getElementById('object').value.trim();
  
  if (!subject || !predicate || !object) {
    alert('Please fill all fields');
    return;
  }
  
  try {
    await fetch(`${API_BASE}/api/add`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ subject, predicate, object })
    });
    
    // Clear inputs
    document.getElementById('subject').value = '';
    document.getElementById('predicate').value = '';
    document.getElementById('object').value = '';
    
    // Reload graph
    loadGraph();
    
  } catch (err) {
    alert('Error: ' + err.message);
    console.error('Add triple error:', err);
  }
}

function showTooltip(title, content) {
  const tooltip = document.getElementById('tooltip');
  tooltip.innerHTML = `<div class="title">${title}</div><div class="path">${content}</div>`;
  tooltip.classList.add('show');
}

function hideTooltip() {
  document.getElementById('tooltip').classList.remove('show');
}
