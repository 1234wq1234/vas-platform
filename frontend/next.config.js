/** @type {import('next').NextConfig} */
const nextConfig = {
  experimental: {
    serverComponentsExternalPackages: ['oracledb'],
  },
};

module.exports = nextConfig;
