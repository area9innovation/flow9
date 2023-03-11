function ToggleButtonGroupControlled({size, value, setValue}) {
  const handleChange = (val) => setValue(val);

  return (
    <ReactBootstrap.ToggleButtonGroup type="checkbox" size={size} value={value} onChange={handleChange}>
      <ReactBootstrap.ToggleButton id="tbg-btn-1" value={1}>
        Option 1
      </ReactBootstrap.ToggleButton>
      <ReactBootstrap.ToggleButton id="tbg-btn-2" value={2}>
        Option 2
      </ReactBootstrap.ToggleButton>
      <ReactBootstrap.ToggleButton id="tbg-btn-3" value={3}>
        Option 3
      </ReactBootstrap.ToggleButton>
    </ReactBootstrap.ToggleButtonGroup>
  );
}