const args = Array.from(tjs.args);
const query = args[args.length - 1] || "";

const items = [
  {
    title: "echo: " + query,
    subtitle: "stub item · args=" + args.length + " · tjs " + tjs.version,
    arg: query,
  },
  {
    title: query.toUpperCase(),
    subtitle: "uppercase variant",
    arg: query.toUpperCase(),
  },
  {
    title: query.split("").reverse().join(""),
    subtitle: "reversed",
    arg: "reversed",
  },
  {
    title: "env.SPIKE_TOKEN = " + (tjs.env.SPIKE_TOKEN || "(unset)"),
    subtitle: "verifies env injection from Swift side",
    arg: "env",
  },
];

console.log(JSON.stringify({ items }));
