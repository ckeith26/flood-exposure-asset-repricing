'use client';

import { useEffect, useState, useCallback, useRef } from 'react';
import ThemeToggle from './ThemeToggle';

const NAV_LINKS = [
  { label: 'Research Question', href: '#research-question' },
  { label: 'Data & Sample', href: '#data-sample' },
  { label: 'Sources', href: '#data-sources' },
  { label: 'Methodology', href: '#methodology' },
  { label: 'Results', href: '#results' },
  { label: 'Robustness', href: '#robustness' },
  { label: 'Limitations', href: '#limitations' },
  { label: 'Data', href: '#data-download' },
  { label: 'About', href: '#about' },
];

export default function Navigation() {
  const [activeSection, setActiveSection] = useState<string>('');
  const [menuOpen, setMenuOpen] = useState(false);
  const menuRef = useRef<HTMLDivElement>(null);
  const contentRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const sectionIds = NAV_LINKS.map((link) => link.href.slice(1));
    const elements = sectionIds
      .map((id) => document.getElementById(id))
      .filter(Boolean) as HTMLElement[];

    if (elements.length === 0) return;

    const visibleSet = new Set<string>();

    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            visibleSet.add(entry.target.id);
          } else {
            visibleSet.delete(entry.target.id);
          }
        });

        const topmost = sectionIds.find((id) => visibleSet.has(id));
        if (topmost) {
          setActiveSection(topmost);
        }
      },
      {
        rootMargin: '-48px 0px -40% 0px',
        threshold: 0,
      }
    );

    elements.forEach((el) => observer.observe(el));
    return () => observer.disconnect();
  }, []);

  // Close menu on click outside
  useEffect(() => {
    if (!menuOpen) return;
    const handler = (e: MouseEvent) => {
      if (menuRef.current && !menuRef.current.contains(e.target as Node)) {
        setMenuOpen(false);
      }
    };
    document.addEventListener('mousedown', handler);
    return () => document.removeEventListener('mousedown', handler);
  }, [menuOpen]);

  const handleClick = useCallback(
    (e: React.MouseEvent<HTMLAnchorElement>, href: string) => {
      e.preventDefault();
      const id = href.slice(1);
      const el = document.getElementById(id);
      if (el) {
        el.scrollIntoView({ behavior: 'smooth' });
      }
      setMenuOpen(false);
    },
    []
  );

  const scrollToTop = useCallback((e: React.MouseEvent) => {
    e.preventDefault();
    window.scrollTo({ top: 0, behavior: 'smooth' });
    setMenuOpen(false);
  }, []);

  return (
    <div ref={menuRef} className="fixed top-0 left-0 right-0 z-50">
      <nav
        className="h-12 flex items-center px-4 md:px-6"
        style={{
          backgroundColor: 'color-mix(in srgb, var(--color-bg) 80%, transparent)',
          backdropFilter: 'blur(12px)',
          WebkitBackdropFilter: 'blur(12px)',
          borderBottom: menuOpen ? 'none' : '1px solid var(--color-border)',
        }}
      >
        {/* Left: Logo */}
        <a
          href="#"
          onClick={scrollToTop}
          className="font-mono font-bold text-sm tracking-wider mr-6 shrink-0 transition-colors duration-200"
          style={{ color: 'var(--color-text)' }}
        >
          FEAR
        </a>

        {/* Center: Section links — desktop */}
        <div className="hidden sm:flex items-center gap-1 overflow-x-auto hide-scrollbar flex-1">
          {NAV_LINKS.map((link) => {
            const isActive = activeSection === link.href.slice(1);
            return (
              <a
                key={link.href}
                href={link.href}
                onClick={(e) => handleClick(e, link.href)}
                className="whitespace-nowrap px-2 py-1 text-xs rounded transition-colors duration-200"
                style={{
                  color: isActive
                    ? 'var(--color-accent)'
                    : 'var(--color-text-secondary)',
                  backgroundColor: isActive
                    ? 'color-mix(in srgb, var(--color-accent) 10%, transparent)'
                    : 'transparent',
                }}
                onMouseEnter={(e) => {
                  if (!isActive) {
                    e.currentTarget.style.color = 'var(--color-text)';
                  }
                }}
                onMouseLeave={(e) => {
                  if (!isActive) {
                    e.currentTarget.style.color = 'var(--color-text-secondary)';
                  }
                }}
              >
                {link.label}
              </a>
            );
          })}
        </div>

        {/* Mobile: spacer + theme toggle + hamburger */}
        <div className="flex-1 sm:hidden" />

        {/* Right: Paper + GitHub + Theme toggle */}
        <div className="flex items-center gap-1.5 shrink-0 sm:ml-4">
          <a
            href="/econ66-fear.pdf"
            target="_blank"
            rel="noopener noreferrer"
            className="hidden sm:inline-flex items-center gap-1.5 px-2.5 py-1 text-xs font-medium rounded border transition-colors duration-200"
            style={{
              color: 'var(--color-text-secondary)',
              borderColor: 'var(--color-border)',
              background: 'transparent',
            }}
            onMouseEnter={(e) => {
              e.currentTarget.style.color = 'var(--color-accent)';
              e.currentTarget.style.borderColor = 'var(--color-accent)';
            }}
            onMouseLeave={(e) => {
              e.currentTarget.style.color = 'var(--color-text-secondary)';
              e.currentTarget.style.borderColor = 'var(--color-border)';
            }}
          >
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
              <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" />
              <polyline points="14 2 14 8 20 8" />
              <line x1="16" y1="13" x2="8" y2="13" />
              <line x1="16" y1="17" x2="8" y2="17" />
              <polyline points="10 9 9 9 8 9" />
            </svg>
            Paper
          </a>
          <a
            href="https://github.com/ckeith26/fear-exposure-asset-repricing"
            target="_blank"
            rel="noopener noreferrer"
            className="hidden sm:inline-flex items-center gap-1.5 px-2.5 py-1 text-xs font-medium rounded border transition-colors duration-200"
            style={{
              color: 'var(--color-text-secondary)',
              borderColor: 'var(--color-border)',
              background: 'transparent',
            }}
            onMouseEnter={(e) => {
              e.currentTarget.style.color = 'var(--color-accent)';
              e.currentTarget.style.borderColor = 'var(--color-accent)';
            }}
            onMouseLeave={(e) => {
              e.currentTarget.style.color = 'var(--color-text-secondary)';
              e.currentTarget.style.borderColor = 'var(--color-border)';
            }}
          >
            <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
              <path d="M12 0C5.37 0 0 5.37 0 12c0 5.31 3.435 9.795 8.205 11.385.6.105.825-.255.825-.57 0-.285-.015-1.23-.015-2.235-3.015.555-3.795-.735-4.035-1.41-.135-.345-.72-1.41-1.23-1.695-.42-.225-1.02-.78-.015-.795.945-.015 1.62.87 1.845 1.23 1.08 1.815 2.805 1.305 3.495.99.105-.78.42-1.305.765-1.605-2.67-.3-5.46-1.335-5.46-5.925 0-1.305.465-2.385 1.23-3.225-.12-.3-.54-1.53.12-3.18 0 0 1.005-.315 3.3 1.23.96-.27 1.98-.405 3-.405s2.04.135 3 .405c2.295-1.56 3.3-1.23 3.3-1.23.66 1.65.24 2.88.12 3.18.765.84 1.23 1.905 1.23 3.225 0 4.605-2.805 5.625-5.475 5.925.435.375.81 1.095.81 2.22 0 1.605-.015 2.895-.015 3.3 0 .315.225.69.825.57A12.02 12.02 0 0 0 24 12c0-6.63-5.37-12-12-12z"/>
            </svg>
            GitHub
          </a>
          <ThemeToggle />
        </div>

        <button
          className="sm:hidden ml-2 w-8 h-8 flex items-center justify-center rounded transition-colors"
          style={{ color: 'var(--color-text)' }}
          onClick={() => setMenuOpen((v) => !v)}
          aria-label="Toggle menu"
        >
          {menuOpen ? (
            <svg width="18" height="18" viewBox="0 0 18 18" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round">
              <path d="M4 4l10 10M14 4L4 14" />
            </svg>
          ) : (
            <svg width="18" height="18" viewBox="0 0 18 18" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round">
              <path d="M2 5h14M2 9h14M2 13h14" />
            </svg>
          )}
        </button>
      </nav>

      {/* Mobile dropdown menu */}
      <div
        ref={contentRef}
        className="sm:hidden overflow-hidden transition-all duration-300 ease-in-out"
        style={{
          maxHeight: menuOpen ? `${(NAV_LINKS.length + 2) * 44 + 16}px` : '0px',
          opacity: menuOpen ? 1 : 0,
          backgroundColor: 'color-mix(in srgb, var(--color-bg) 95%, transparent)',
          backdropFilter: 'blur(12px)',
          WebkitBackdropFilter: 'blur(12px)',
          borderBottom: menuOpen ? '1px solid var(--color-border)' : 'none',
        }}
      >
        <div className="flex flex-col py-2 px-4">
          {NAV_LINKS.map((link) => {
            const isActive = activeSection === link.href.slice(1);
            return (
              <a
                key={link.href}
                href={link.href}
                onClick={(e) => handleClick(e, link.href)}
                className="py-2.5 px-3 text-sm rounded transition-colors duration-200"
                style={{
                  color: isActive
                    ? 'var(--color-accent)'
                    : 'var(--color-text-secondary)',
                  backgroundColor: isActive
                    ? 'color-mix(in srgb, var(--color-accent) 10%, transparent)'
                    : 'transparent',
                }}
              >
                {link.label}
              </a>
            );
          })}
          <div className="flex gap-2 pt-2 px-3">
            <a
              href="/econ66-fear.pdf"
              target="_blank"
              rel="noopener noreferrer"
              className="flex-1 inline-flex items-center justify-center gap-1.5 py-2 text-sm font-medium rounded border transition-colors duration-200"
              style={{
                color: 'var(--color-text-secondary)',
                borderColor: 'var(--color-border)',
                background: 'transparent',
              }}
            >
              <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
                <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" />
                <polyline points="14 2 14 8 20 8" />
                <line x1="16" y1="13" x2="8" y2="13" />
                <line x1="16" y1="17" x2="8" y2="17" />
                <polyline points="10 9 9 9 8 9" />
              </svg>
              Paper
            </a>
            <a
              href="https://github.com/ckeith26/fear-exposure-asset-repricing"
              target="_blank"
              rel="noopener noreferrer"
              className="flex-1 inline-flex items-center justify-center gap-1.5 py-2 text-sm font-medium rounded border transition-colors duration-200"
              style={{
                color: 'var(--color-text-secondary)',
                borderColor: 'var(--color-border)',
                background: 'transparent',
              }}
            >
              <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
                <path d="M12 0C5.37 0 0 5.37 0 12c0 5.31 3.435 9.795 8.205 11.385.6.105.825-.255.825-.57 0-.285-.015-1.23-.015-2.235-3.015.555-3.795-.735-4.035-1.41-.135-.345-.72-1.41-1.23-1.695-.42-.225-1.02-.78-.015-.795.945-.015 1.62.87 1.845 1.23 1.08 1.815 2.805 1.305 3.495.99.105-.78.42-1.305.765-1.605-2.67-.3-5.46-1.335-5.46-5.925 0-1.305.465-2.385 1.23-3.225-.12-.3-.54-1.53.12-3.18 0 0 1.005-.315 3.3 1.23.96-.27 1.98-.405 3-.405s2.04.135 3 .405c2.295-1.56 3.3-1.23 3.3-1.23.66 1.65.24 2.88.12 3.18.765.84 1.23 1.905 1.23 3.225 0 4.605-2.805 5.625-5.475 5.925.435.375.81 1.095.81 2.22 0 1.605-.015 2.895-.015 3.3 0 .315.225.69.825.57A12.02 12.02 0 0 0 24 12c0-6.63-5.37-12-12-12z"/>
              </svg>
              GitHub
            </a>
          </div>
        </div>
      </div>
    </div>
  );
}
