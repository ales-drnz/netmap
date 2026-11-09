<script lang="ts">
  // A button that copies a value (ui.copy: clipboard API with the http fallback, + toast).
  //   <CopyButton text={ip} />                          icon-only, aria "Copy 10.0.0.1"
  //   <CopyButton text={ip} label="Copy my IP · {ip}" />  labelled secondary button
  //   variant / size as in Button.svelte (default: secondary, md)
  import { t } from '$lib/i18n/index.svelte';
  import { ui } from '$lib/ui.svelte';
  import Button from './Button.svelte';

  let {
    text,
    label,
    variant = 'secondary',
    size = 'md',
  }: { text: string; label?: string; variant?: 'primary' | 'secondary' | 'ghost'; size?: 'md' | 'sm' } = $props();
</script>

<Button
  {variant}
  {size}
  icon="i-copy"
  iconOnly={!label}
  label={label ?? t('common.copyThing', { text })}
  onclick={(e: MouseEvent) => {
    e.stopPropagation();
    ui.copy(text);
  }}
/>
