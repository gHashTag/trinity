/**
 * TRI Production Dashboard - Static Version
 *
 * Production-ready dashboard with mock data for demonstration.
 * Shows:
 * - Command count and coverage
 * - System health metrics
 * - Recent alerts
 * - Build status
 */

import React, { useState, useEffect } from 'react';
import { motion } from 'framer-motion';

interface MetricCardProps {
  title: string;
  value: string | number;
  unit?: string;
  color: string;
  trend?: 'up' | 'down' | 'neutral';
}

const MetricCard: React.FC<MetricCardProps> = ({ title, value, unit, color, trend = 'neutral' }) => (
  <motion.div
    initial={{ opacity: 0, y: 20 }}
    animate={{ opacity: 1, y: 0 }}
    className="bg-gray-800/50 rounded-lg p-6 border border-gray-700"
  >
    <div className="flex items-center justify-between mb-2">
      <h3 className="text-gray-400 text-sm">{title}</h3>
      {trend !== 'neutral' && (
        <span className={`text-xs ${trend === 'up' ? 'text-green-400' : 'text-red-400'}`}>
          {trend === 'up' ? '↑' : '↓'}
        </span>
      )}
    </div>
    <div className="flex items-baseline">
      <span className={`text-3xl font-bold`} style={{ color }}>{value}</span>
      {unit && <span className="text-gray-400 ml-2">{unit}</span>}
    </div>
  </motion.div>
);

interface Alert {
  id: string;
  type: 'info' | 'warning' | 'error' | 'success';
  message: string;
  timestamp: string;
}

const AlertItem: React.FC<{ alert: Alert }> = ({ alert }) => {
  const colors = {
    info: 'bg-blue-900/20 border-blue-500/30 text-blue-400',
    warning: 'bg-yellow-900/20 border-yellow-500/30 text-yellow-400',
    error: 'bg-red-900/20 border-red-500/30 text-red-400',
    success: 'bg-green-900/20 border-green-500/30 text-green-400',
  };

  return (
    <div className={`p-3 rounded border ${colors[alert.type]} mb-2`}>
      <div className="flex justify-between items-start">
        <p className="text-sm flex-1">{alert.message}</p>
        <span className="text-xs opacity-70 ml-2">{alert.timestamp}</span>
      </div>
    </div>
  );
};

export default function ProductionDashboard() {
  const [currentTime, setCurrentTime] = useState(new Date());

  useEffect(() => {
    const timer = setInterval(() => setCurrentTime(new Date()), 1000);
    return () => clearInterval(timer);
  }, []);

  // Mock data
  const metrics = {
    totalCommands: 47,
    commandCoverage: 94.7,
    systemHealth: 98.2,
    activeNodes: 12,
    uptime: '99.9%',
  };

  const alerts: Alert[] = [
    {
      id: '1',
      type: 'success',
      message: 'Cycle 98 deployment completed successfully',
      timestamp: '2 min ago',
    },
    {
      id: '2',
      type: 'info',
      message: 'New sacred intelligence patterns indexed',
      timestamp: '15 min ago',
    },
    {
      id: '3',
      type: 'warning',
      message: 'Memory usage approaching threshold (82%)',
      timestamp: '1 hour ago',
    },
  ];

  const buildStatus = [
    { name: 'website', status: 'passing', branch: 'main', lastBuild: '5 min ago' },
    { name: 'docsite', status: 'passing', branch: 'main', lastBuild: '5 min ago' },
    { name: 'trinity-core', status: 'passing', branch: 'main', lastBuild: '10 min ago' },
  ];

  return (
    <div className="min-h-screen bg-gray-900">
      {/* Header */}
      <header className="sticky top-0 z-50 bg-gray-900/95 backdrop-blur-sm border-b border-gray-700">
        <div className="container mx-auto px-4 py-4">
          <div className="flex items-center justify-between">
            <div>
              <h1 className="text-2xl font-bold bg-gradient-to-r from-yellow-400 via-cyan-400 to-purple-400 bg-clip-text text-transparent">
                TRI Production Dashboard
              </h1>
              <p className="text-gray-400 text-sm mt-1">
                Last updated: {currentTime.toLocaleString()}
              </p>
            </div>
            <div className="flex items-center space-x-2">
              <div className="w-3 h-3 bg-green-500 rounded-full animate-pulse" />
              <span className="text-green-400 text-sm">All Systems Operational</span>
            </div>
          </div>
        </div>
      </header>

      {/* Main Content */}
      <main className="container mx-auto px-4 py-6">
        {/* Metrics Grid */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
          <MetricCard
            title="Total Commands"
            value={metrics.totalCommands}
            color="#ffd700"
            trend="up"
          />
          <MetricCard
            title="Command Coverage"
            value={metrics.commandCoverage}
            unit="%"
            color="#00ccff"
          />
          <MetricCard
            title="System Health"
            value={metrics.systemHealth}
            unit="%"
            color="#10b981"
          />
          <MetricCard
            title="Active Nodes"
            value={metrics.activeNodes}
            color="#aa66ff"
          />
        </div>

        {/* Two Column Layout */}
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-8">
          {/* Alerts Column */}
          <motion.div
            initial={{ opacity: 0, x: -20 }}
            animate={{ opacity: 1, x: 0 }}
            className="bg-gray-800/30 rounded-lg p-6 border border-gray-700"
          >
            <h2 className="text-xl font-semibold text-white mb-4">Recent Alerts</h2>
            <div className="space-y-2 max-h-96 overflow-y-auto">
              {alerts.map((alert) => (
                <AlertItem key={alert.id} alert={alert} />
              ))}
            </div>
          </motion.div>

          {/* Build Status Column */}
          <motion.div
            initial={{ opacity: 0, x: 20 }}
            animate={{ opacity: 1, x: 0 }}
            className="bg-gray-800/30 rounded-lg p-6 border border-gray-700"
          >
            <h2 className="text-xl font-semibold text-white mb-4">Build Status</h2>
            <div className="space-y-3">
              {buildStatus.map((build, index) => (
                <div key={index} className="bg-gray-800/50 rounded-lg p-4 border border-gray-700">
                  <div className="flex items-center justify-between mb-2">
                    <div className="flex items-center space-x-2">
                      <div className={`w-2 h-2 rounded-full ${build.status === 'passing' ? 'bg-green-500' : 'bg-red-500'}`} />
                      <span className="text-white font-semibold">{build.name}</span>
                    </div>
                    <span className={`text-xs px-2 py-1 rounded ${build.status === 'passing' ? 'bg-green-900/30 text-green-400' : 'bg-red-900/30 text-red-400'}`}>
                      {build.status}
                    </span>
                  </div>
                  <div className="flex justify-between text-xs text-gray-400">
                    <span>Branch: {build.branch}</span>
                    <span>Last build: {build.lastBuild}</span>
                  </div>
                </div>
              ))}
            </div>
          </motion.div>
        </div>

        {/* Command Coverage Breakdown */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          className="bg-gray-800/30 rounded-lg p-6 border border-gray-700"
        >
          <h2 className="text-xl font-semibold text-white mb-4">Command Coverage</h2>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div>
              <div className="flex justify-between items-center mb-2">
                <span className="text-gray-300">Core Commands</span>
                <span className="text-cyan-400 font-semibold">23/24 (95.8%)</span>
              </div>
              <div className="w-full bg-gray-700 rounded-full h-2">
                <div className="bg-cyan-500 h-2 rounded-full" style={{ width: '95.8%' }} />
              </div>
            </div>
            <div>
              <div className="flex justify-between items-center mb-2">
                <span className="text-gray-300">SWE Agent</span>
                <span className="text-purple-400 font-semibold">8/8 (100%)</span>
              </div>
              <div className="w-full bg-gray-700 rounded-full h-2">
                <div className="bg-purple-500 h-2 rounded-full" style={{ width: '100%' }} />
              </div>
            </div>
            <div>
              <div className="flex justify-between items-center mb-2">
                <span className="text-gray-300">TV Commands</span>
                <span className="text-yellow-400 font-semibold">16/18 (88.9%)</span>
              </div>
              <div className="w-full bg-gray-700 rounded-full h-2">
                <div className="bg-yellow-500 h-2 rounded-full" style={{ width: '88.9%' }} />
              </div>
            </div>
          </div>
        </motion.div>

        {/* System Health Details */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.2 }}
          className="mt-6 bg-gray-800/30 rounded-lg p-6 border border-gray-700"
        >
          <h2 className="text-xl font-semibold text-white mb-4">System Health</h2>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
            <div className="bg-gray-800/50 rounded p-4 border border-gray-700">
              <p className="text-gray-400 text-xs mb-1">Uptime</p>
              <p className="text-green-400 text-xl font-bold">{metrics.uptime}</p>
            </div>
            <div className="bg-gray-800/50 rounded p-4 border border-gray-700">
              <p className="text-gray-400 text-xs mb-1">Response Time</p>
              <p className="text-cyan-400 text-xl font-bold">42ms</p>
            </div>
            <div className="bg-gray-800/50 rounded p-4 border border-gray-700">
              <p className="text-gray-400 text-xs mb-1">Error Rate</p>
              <p className="text-yellow-400 text-xl font-bold">0.01%</p>
            </div>
            <div className="bg-gray-800/50 rounded p-4 border border-gray-700">
              <p className="text-gray-400 text-xs mb-1">Memory</p>
              <p className="text-purple-400 text-xl font-bold">82%</p>
            </div>
          </div>
        </motion.div>
      </main>

      {/* Footer */}
      <footer className="container mx-auto px-4 py-6 mt-8 border-t border-gray-700">
        <div className="flex flex-col md:flex-row justify-between items-center text-sm text-gray-400">
          <p>TRI Production Dashboard v1.0.0</p>
          <p className="mt-2 md:mt-0">
            Powered by Trinity Framework | φ² + 1/φ² = 3
          </p>
        </div>
      </footer>
    </div>
  );
}
