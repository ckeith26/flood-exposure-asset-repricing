"use client";

import dynamic from "next/dynamic";
import { metadata, eventStudyMain } from "@/lib/data";

const TreatmentMap = dynamic(() => import("@/components/TreatmentMap"), {
  ssr: false,
  loading: () => (
    <div
      className="w-full rounded-lg animate-pulse"
      style={{
        background: "var(--color-surface)",
        aspectRatio: "100 / 58",
      }}
    />
  ),
});

const EventStudyChart = dynamic(() => import("@/components/EventStudyChart"), {
  ssr: false,
  loading: () => (
    <div
      className="w-full rounded-lg animate-pulse"
      style={{ background: "var(--color-surface)", height: "360px" }}
    />
  ),
});

export default function Hero() {
  return (
    <div className="relative flex flex-col items-center px-6 pt-20 pb-10 overflow-hidden">
      {/* Subtle background gradient */}
      <div
        className="absolute inset-0 opacity-30"
        style={{
          background:
            "radial-gradient(ellipse at 50% 80%, rgba(59,130,246,0.08) 0%, transparent 60%)",
        }}
      />

      <div className="relative z-10 text-center max-w-4xl mb-8">
        {/* Acronym expansion */}
        <p className="font-mono text-sm tracking-[0.15em] uppercase mb-3" style={{ color: "var(--color-accent)" }}>
          Flood Exposure and Asset Repricing
        </p>

        {/* Title */}
        <h1 className="text-3xl md:text-5xl font-bold tracking-tight leading-tight mb-4">
          {metadata.title}
        </h1>

        {/* Subtitle */}
        <p className="text-base md:text-lg mb-6" style={{ color: "var(--color-text-secondary)" }}>
          {metadata.subtitle}
        </p>

        {/* Key finding - inline compact */}
        <div className="flex items-center justify-center gap-4 mb-2">
          <span className="font-mono text-4xl md:text-5xl font-bold" style={{ color: "var(--color-negative)" }}>
            {metadata.headline_pct}%
          </span>
          <span className="text-sm text-left max-w-xs" style={{ color: "var(--color-text-secondary)" }}>
            {metadata.headline_description}
          </span>
        </div>
        <p className="text-xs font-mono mb-4" style={{ color: "var(--color-text-secondary)" }}>
          {metadata.n_observations_regression} zip-quarter obs &middot; {metadata.analysis_window.start}&ndash;{metadata.analysis_window.end}
        </p>

        {/* Author */}
        <p className="text-xs font-mono" style={{ color: "var(--color-text-secondary)" }}>
          by {metadata.author}
        </p>
        <p className="text-xs font-mono mt-1" style={{ color: "var(--color-text-secondary)" }}>
          Professor Apoorv Gupta &middot; Winter 2026
        </p>
        <p className="text-xs font-mono mt-1" style={{ color: "var(--color-text-secondary)" }}>
          {metadata.course}
        </p>

        {/* Paper & GitHub buttons */}
        <div className="flex items-center justify-center gap-3 mt-5">
          <a
            href="/econ66-fear.pdf"
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center gap-2 px-4 py-2 text-sm font-medium rounded-md border transition-colors duration-200"
            style={{
              color: "var(--color-accent)",
              borderColor: "var(--color-accent)",
              background: "transparent",
            }}
            onMouseEnter={(e) => {
              e.currentTarget.style.background = "var(--color-accent)";
              e.currentTarget.style.color = "#ffffff";
            }}
            onMouseLeave={(e) => {
              e.currentTarget.style.background = "transparent";
              e.currentTarget.style.color = "var(--color-accent)";
            }}
          >
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
              <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" />
              <polyline points="14 2 14 8 20 8" />
              <line x1="16" y1="13" x2="8" y2="13" />
              <line x1="16" y1="17" x2="8" y2="17" />
              <polyline points="10 9 9 9 8 9" />
            </svg>
            Read the Paper
          </a>
          <a
            href="https://github.com/ckeith26/fear-exposure-asset-repricing"
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center gap-2 px-4 py-2 text-sm font-medium rounded-md border transition-colors duration-200"
            style={{
              color: "var(--color-text-secondary)",
              borderColor: "var(--color-border)",
              background: "transparent",
            }}
            onMouseEnter={(e) => {
              e.currentTarget.style.color = "var(--color-text)";
              e.currentTarget.style.borderColor = "var(--color-text)";
            }}
            onMouseLeave={(e) => {
              e.currentTarget.style.color = "var(--color-text-secondary)";
              e.currentTarget.style.borderColor = "var(--color-border)";
            }}
          >
            <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
              <path d="M12 0C5.37 0 0 5.37 0 12c0 5.31 3.435 9.795 8.205 11.385.6.105.825-.255.825-.57 0-.285-.015-1.23-.015-2.235-3.015.555-3.795-.735-4.035-1.41-.135-.345-.72-1.41-1.23-1.695-.42-.225-1.02-.78-.015-.795.945-.015 1.62.87 1.845 1.23 1.08 1.815 2.805 1.305 3.495.99.105-.78.42-1.305.765-1.605-2.67-.3-5.46-1.335-5.46-5.925 0-1.305.465-2.385 1.23-3.225-.12-.3-.54-1.53.12-3.18 0 0 1.005-.315 3.3 1.23.96-.27 1.98-.405 3-.405s2.04.135 3 .405c2.295-1.56 3.3-1.23 3.3-1.23.66 1.65.24 2.88.12 3.18.765.84 1.23 1.905 1.23 3.225 0 4.605-2.805 5.625-5.475 5.925.435.375.81 1.095.81 2.22 0 1.605-.015 2.895-.015 3.3 0 .315.225.69.825.57A12.02 12.02 0 0 0 24 12c0-6.63-5.37-12-12-12z"/>
            </svg>
            View on GitHub
          </a>
        </div>
      </div>

      {/* Map */}
      <div className="relative z-10 w-full max-w-6xl">
        <TreatmentMap />
      </div>

      {/* Main result preview */}
      <div className="relative z-10 w-full max-w-4xl mt-12">
        <p
          className="text-sm mb-6 text-center max-w-2xl mx-auto"
          style={{ color: "var(--color-text-secondary)" }}
        >
          Home values decline gradually after LOMR flood zone reclassification,
          reaching &minus;2.8% after four or more years. Pre-treatment
          coefficients near zero confirm the parallel trends assumption.
        </p>
        <EventStudyChart {...eventStudyMain} />
      </div>
    </div>
  );
}
