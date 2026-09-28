import type { NextConfig } from "next";
import { BASE_PATH, PUBLIC_HOST } from "./src/lib/config";

const nextConfig: NextConfig = {
  // Served at https://alphaexperiments.com/heretic-inference: the domain's Caddy forwards this path to Vercel.
  basePath: BASE_PATH,
  poweredByHeader: false,
  experimental: {
    // Server Actions compare Origin with the host Vercel sees (the *.vercel.app name Caddy connects to), so the
    // public host has to be allowed explicitly.
    serverActions: { allowedOrigins: [PUBLIC_HOST] },
  },
  async headers() {
    return [
      {
        source: "/:path*",
        headers: [
          { key: "X-Content-Type-Options", value: "nosniff" },
          { key: "Referrer-Policy", value: "no-referrer" },
          { key: "Content-Security-Policy", value: "frame-ancestors 'none'; base-uri 'none'; object-src 'none'" },
          { key: "Permissions-Policy", value: "camera=(), microphone=(), geolocation=()" },
          { key: "X-Robots-Tag", value: "noindex, nofollow" },
        ],
      },
    ];
  },
};

export default nextConfig;
