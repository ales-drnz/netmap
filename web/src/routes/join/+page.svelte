<script lang="ts">
  // Join: the page to send to a newcomer (outside the app shell, one column,
  // printable). Four steps: install ZeroTier → join the network id → name the
  // device person-type and tell the admin → once authorized, open Netmap at the
  // hub's ZeroTier IP. "Copy instructions as a message" puts the same steps in
  // one self-contained text (id, command, naming convention, final URL).
  import { page } from '$app/state';
  import Button from '$lib/components/Button.svelte';
  import CopyButton from '$lib/components/CopyButton.svelte';
  import Icon from '$lib/components/Icon.svelte';
  import { t } from '$lib/i18n/index.svelte';
  import { live } from '$lib/live.svelte';
  import { cap, ownerOf, typeOf } from '$lib/naming';
  import { ui } from '$lib/ui.svelte';

  const netId = $derived(live.snap?.networkId ?? '');
  const netName = $derived(live.snap?.networkName ?? '');
  const cmd = $derived(`zerotier-cli join ${netId || '<network-id>'}`);

  // Netmap listens on the hub's ZeroTier address. When this page is already
  // opened through that address keep its port; otherwise assume the default 8082.
  const hubUrl = $derived.by(() => {
    const ip = live.hub?.ips[0] ?? null;
    if (!ip) return null;
    const here = page.url;
    const port = here.hostname === ip ? here.port : '8082';
    return `http://${ip}${port && port !== '80' ? `:${port}` : ''}`;
  });

  let name = $state('');
  const sample = 'alice-laptop';
  const probe = $derived(name.trim() || sample);
  const owner = $derived(ownerOf(probe));
  const type = $derived(typeOf(probe));
  const clean = $derived(/^[a-z0-9]+(-[a-z0-9]+)+$/.test(probe));
  const taken = $derived(name.trim() ? live.nodes.some((n) => n.name.toLowerCase() === name.trim().toLowerCase()) : false);
  const EXAMPLES = ['alice-pc', 'bob-phone', 'carol-laptop-work', 'home-tv'];
  const OS = ['Windows', 'macOS', 'Linux', 'Android', 'iOS'];

  const message = $derived(
    [
      t('join.msgHead', { net: netName || 'ZeroTier' }),
      '',
      `1. ${t('join.msg1')} https://www.zerotier.com/download/`,
      `2. ${t('join.msg2', { id: netId || '…' })}`,
      `   ${cmd}`,
      `3. ${t('join.msg3')}`,
      `4. ${hubUrl ? t('join.msg4', { url: hubUrl }) : t('join.msg4NoUrl')}`,
    ].join('\n'),
  );
</script>

<article class="join">
  <header class="j-head">
    <h1>{netName ? t('join.titleNet', { net: netName }) : t('join.title')}</h1>
    <p class="t-body text-2">{t('join.intro')}</p>
    <div class="j-actions no-print">
      <Button variant="primary" icon="i-copy" onclick={() => ui.copy(message)}>{t('join.copyMsg')}</Button>
      <Button variant="ghost" icon="i-printer" onclick={() => window.print()}>{t('join.print')}</Button>
    </div>
  </header>

  <ol class="steps">
    <li class="step">
      <span class="n num" aria-hidden="true">1</span>
      <div class="s-b">
        <h2 class="t-h2">{t('join.s1')}</h2>
        <p class="text-2">{t('join.s1Text')}</p>
        <div class="os">
          {#each OS as o (o)}<Button size="sm" href="https://www.zerotier.com/download/" external>{o}</Button>{/each}
        </div>
        <p class="print-only mono">https://www.zerotier.com/download/</p>
      </div>
    </li>

    <li class="step">
      <span class="n num" aria-hidden="true">2</span>
      <div class="s-b">
        <h2 class="t-h2">{t('join.s2')}</h2>
        <p class="text-2">{t('join.s2Text')}</p>
        <div class="field">
          <span class="f-l t-micro t-upper text-3">{t('join.netId')}</span>
          <span class="mono f-v">{netId || '…'}</span>
          {#if netId}<CopyButton text={netId} size="sm" />{/if}
        </div>
        <p class="text-2">{t('join.s2Cmd')}</p>
        <div class="field cmd">
          <span class="mono f-v"><span class="text-3 no-select">$&nbsp;</span>{cmd}</span>
          <CopyButton text={cmd} size="sm" />
        </div>
        <p class="t-caption text-3">{t('join.sudo')}</p>
      </div>
    </li>

    <li class="step">
      <span class="n num" aria-hidden="true">3</span>
      <div class="s-b">
        <h2 class="t-h2">{t('join.s3')}</h2>
        <p class="text-2">{t('join.s3Text')} <span class="mono">{t('join.pattern')}</span>.</p>
        <label class="try no-print">
          <span class="t-label">{t('join.try')}</span>
          <input class="input" bind:value={name} placeholder={sample} spellcheck="false" autocomplete="off" autocapitalize="none" />
        </label>
        <div class="examples no-print">
          {#each EXAMPLES as ex (ex)}<button type="button" class="ex mono" onclick={() => (name = ex)}>{ex}</button>{/each}
        </div>
        <dl class="parse" aria-live="polite">
          <div>
            <dt class="t-caption text-3">{t('join.person')}</dt>
            <dd class:bad={!owner}><Icon name="i-user" size={14} />{owner ? cap(owner) : t('join.noOwner')}</dd>
          </div>
          <div>
            <dt class="t-caption text-3">{t('join.type')}</dt>
            <dd class:bad={!type}><Icon name="i-{type ?? 'iot'}" size={14} />{type ? t(`join.ty.${type}`) : t('join.noType')}</dd>
          </div>
          <div class="hint">
            {#if !name.trim()}<span class="text-3">{t('join.example', { name: sample })}</span>
            {:else if taken}<span class="warn"><Icon name="i-warn" size={14} />{t('join.taken')}</span>
            {:else if !clean}<span class="warn"><Icon name="i-warn" size={14} />{t('join.notClean')}</span>
            {:else if owner && type}<span class="okk"><Icon name="i-check" size={14} />{t('join.good')}</span>{/if}
          </div>
        </dl>
        <p class="text-2">{t('join.s3Tell')}</p>
      </div>
    </li>

    <li class="step">
      <span class="n num" aria-hidden="true">4</span>
      <div class="s-b">
        <h2 class="t-h2">{t('join.s4')}</h2>
        <p class="text-2">{t('join.s4Text')}</p>
        {#if hubUrl}
          <div class="field">
            <span class="mono f-v">{hubUrl}</span>
            <CopyButton text={hubUrl} size="sm" />
          </div>
        {:else}
          <p class="t-caption text-3">{t('join.noHub')}</p>
        {/if}
      </div>
    </li>
  </ol>

  <section class="msg no-print" aria-labelledby="msg-h">
    <div class="msg-h">
      <h2 id="msg-h" class="t-h3">{t('join.msgTitle')}</h2>
      <Button size="sm" icon="i-copy" onclick={() => ui.copy(message)}>{t('common.copy')}</Button>
    </div>
    <pre class="mono">{message}</pre>
  </section>
</article>

<style>
  .join {
    display: flex;
    flex-direction: column;
    gap: 32px;
  }
  .j-head {
    display: flex;
    flex-direction: column;
    gap: 8px;
  }
  .j-actions {
    display: flex;
    flex-wrap: wrap;
    gap: 8px;
    margin-top: 8px;
  }
  .steps {
    display: flex;
    flex-direction: column;
    background: var(--surface);
    border-radius: var(--r-lg);
  }
  .step {
    display: grid;
    grid-template-columns: 28px minmax(0, 1fr);
    gap: 16px;
    padding: 20px;
  }
  .step + .step {
    border-top: 1px solid var(--line);
  }
  .n {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 28px;
    height: 28px;
    border-radius: var(--r-full);
    background: var(--fill);
    color: var(--text-2);
    font-weight: 600;
  }
  .s-b {
    display: flex;
    flex-direction: column;
    gap: 10px;
    min-width: 0;
  }
  .s-b h2 {
    line-height: 28px;
  }
  .os {
    display: flex;
    flex-wrap: wrap;
    gap: 8px;
  }
  .field {
    display: flex;
    align-items: center;
    gap: 12px;
    min-height: 40px;
    padding: 4px 4px 4px 12px;
    background: var(--fill);
    border-radius: var(--r-md);
    min-width: 0;
  }
  .f-l {
    flex-shrink: 0;
  }
  .f-v {
    flex: 1;
    min-width: 0;
    overflow-wrap: anywhere;
    font-size: 13px;
    color: var(--text);
  }
  .no-select {
    user-select: none;
  }
  .try {
    display: flex;
    flex-direction: column;
    gap: 6px;
    max-width: 360px;
  }
  .try .input {
    font-family: var(--mono);
  }
  .examples {
    display: flex;
    flex-wrap: wrap;
    gap: 6px;
  }
  .ex {
    height: 24px;
    padding: 0 8px;
    border: 0;
    border-radius: var(--r-sm);
    background: var(--fill);
    color: var(--text-2);
    font-size: 12px;
    cursor: pointer;
  }
  .ex:hover {
    background: var(--fill-strong);
    color: var(--text);
  }
  .parse {
    display: flex;
    flex-wrap: wrap;
    align-items: flex-end;
    gap: 8px 24px;
    padding: 10px 12px;
    border-radius: var(--r-md);
    background: var(--surface-2);
  }
  .parse > div {
    display: flex;
    flex-direction: column;
    gap: 2px;
  }
  .parse dd {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    font-weight: 500;
  }
  .parse dd :global(svg) {
    color: var(--text-3);
  }
  .parse dd.bad {
    color: var(--text-3);
    font-weight: 400;
  }
  .hint {
    margin-left: auto;
  }
  .hint span {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    font-size: 12px;
  }
  .warn {
    color: var(--relay-fg);
  }
  .okk {
    color: var(--ok-fg);
  }
  .msg {
    display: flex;
    flex-direction: column;
    gap: 10px;
  }
  .msg-h {
    display: flex;
    align-items: center;
    justify-content: space-between;
  }
  pre {
    margin: 0;
    padding: 14px 16px;
    background: var(--surface);
    border-radius: var(--r-lg);
    white-space: pre-wrap;
    overflow-wrap: anywhere;
    line-height: 20px;
    color: var(--text-2);
  }
  .print-only {
    display: none;
  }
  @media (max-width: 767px) {
    .step {
      grid-template-columns: 24px minmax(0, 1fr);
      gap: 12px;
      padding: 16px;
    }
    .n {
      width: 24px;
      height: 24px;
      margin-top: 2px;
    }
    .hint {
      margin-left: 0;
      flex-basis: 100%;
    }
  }
  @media print {
    .no-print {
      display: none !important;
    }
    .print-only {
      display: block;
    }
    .steps,
    .field,
    .parse {
      background: none;
      border-color: #ccc;
    }
    .step {
      break-inside: avoid;
    }
  }
</style>
