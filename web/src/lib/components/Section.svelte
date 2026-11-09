<script lang="ts">
  // Section: h3 title + optional note + optional action on the right, then the
  // content on --surface with a hairline border (r-lg). Never nest sections:
  // split the inside with hairlines (`.rows`, KeyValueList) instead.
  //   <Section title="Services" note="checked every 20 s" id="services">
  //     {#snippet action()}<a class="more" href="…">All →</a>{/snippet}
  //     <div class="rows">…</div>
  //   </Section>
  // pad: 16px padding inside the box (off for row lists, which pad themselves)
  // plain: no box, just title + hairline (for content that isn't an "object")
  // headingLevel: 2 when the section is a top-level block of the page
  import type { Snippet } from 'svelte';

  let {
    title,
    note,
    id,
    pad = false,
    plain = false,
    headingLevel = 3,
    action,
    children,
    class: cls = '',
  }: {
    title?: string;
    note?: string | null;
    id?: string;
    pad?: boolean;
    plain?: boolean;
    headingLevel?: 2 | 3;
    action?: Snippet;
    children: Snippet;
    class?: string;
  } = $props();
</script>

<section class="section {cls}" class:plain {id} aria-label={title}>
  {#if title || action}
    <header class="section-h">
      {#if title}<svelte:element this={`h${headingLevel}`} class="t-h3">{title}</svelte:element>{/if}
      {#if note}<span class="note">{note}</span>{/if}
      {#if action}<div class="act">{@render action()}</div>{/if}
    </header>
  {/if}
  <div class="section-b" class:pad>{@render children()}</div>
</section>
