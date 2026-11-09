<script lang="ts">
  // Popover / menu anchored to a trigger button (status pill, ⋯ menu, filters…).
  // Opens on click, closes on outside click, Esc (focus goes back to the
  // trigger) and when the content calls `close` (e.g. after a link).
  //   <Popover label="Menu" triggerClass="btn ghost icon">
  //     {#snippet trigger()}<Icon name="i-dots" />{/snippet}
  //     {#snippet children(close)}<a class="menu-item" href="/join" onclick={close}>…</a>{/snippet}
  //   </Popover>
  // The panel uses .menu (surface, --sh-pop, r-lg); `panelClass` adds to it.
  import type { Snippet } from 'svelte';

  let {
    label,
    triggerClass = '',
    panelClass = '',
    role = 'menu',
    trigger,
    children,
  }: {
    label: string;
    triggerClass?: string;
    panelClass?: string;
    /** 'menu' for action lists, 'dialog' for informative panels */
    role?: 'menu' | 'dialog';
    trigger: Snippet;
    children: Snippet<[() => void]>;
  } = $props();

  let open = $state(false);
  let anchor: HTMLDivElement | undefined = $state();
  let btn: HTMLButtonElement | undefined = $state();
  const id = `pop-${Math.random().toString(36).slice(2, 8)}`;

  const close = () => (open = false);
</script>

<svelte:window
  onpointerdown={(e) => {
    if (open && anchor && !anchor.contains(e.target as Node)) close();
  }}
  onkeydown={(e) => {
    if (open && e.key === 'Escape') {
      e.stopPropagation();
      close();
      btn?.focus();
    }
  }}
/>

<div class="pop-anchor" bind:this={anchor}>
  <button
    bind:this={btn}
    type="button"
    class={triggerClass}
    aria-label={label}
    aria-haspopup={role === 'menu' ? 'menu' : 'dialog'}
    aria-expanded={open}
    aria-controls={open ? id : undefined}
    onclick={() => (open = !open)}>{@render trigger()}</button
  >
  {#if open}
    <div {id} class="menu {panelClass}" {role} aria-label={label}>{@render children(close)}</div>
  {/if}
</div>
