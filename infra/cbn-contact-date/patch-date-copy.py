from pathlib import Path

path = Path('/app/app/javascript/dashboard/components/CustomAttribute.vue')
source = path.read_text()

def replace_once(old, new):
    global source
    if source.count(old) != 1:
        raise RuntimeError('Unexpected CustomAttribute source; refusing patch')
    source = source.replace(old, new, 1)

replace_once("const DATE_FORMAT = 'yyyy-MM-dd';", """const DATE_FORMAT = 'yyyy-MM-dd';
// Birth dates are calendar days. Preserve the stored day without timezone conversion.
const cbnBirthDateLabel = value => {
  const parts = String(value ?? '').match(/^(\\d{4})-(\\d{2})-(\\d{2})(?:T.*)?$/);
  return parts ? `${parts[3]}/${parts[2]}/${parts[1]}` : value;
};""")
replace_once("    displayValue() {\n", """    displayValue() {
      if (this.attributeKey === 'cbn_data_nascimento' && this.hasValue) {
        return cbnBirthDateLabel(this.value);
      }
""")
replace_once("      this.$emit('copy', this.value);", """      const value = this.attributeKey === 'cbn_data_nascimento'
        ? cbnBirthDateLabel(this.value)
        : this.value;
      this.$emit('copy', value);""")
path.write_text(source)

# The runtime image retains the original Vite config. Disable production source
# maps in this build stage, matching the previous UI build's memory budget.
config = Path('/app/vite.config.ts')
source = config.read_text()
anchor = 'export default defineConfig({'
if 'build: { sourcemap: false }' not in source:
    if source.count(anchor) != 1:
        raise RuntimeError('Unexpected Vite config; refusing patch')
    source = source.replace(anchor, anchor + '\n  build: { sourcemap: false },', 1)
    config.write_text(source)
