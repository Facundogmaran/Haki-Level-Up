// Ícono "ninguno" a línea (círculo con barra), mismo estilo que IconoBolsa
// y el lápiz de editar, para no romper la estética de la grilla.
export default function IconoNinguno({ size = 26 }) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.4"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      <circle cx="12" cy="12" r="8.5" />
      <path d="M6.5 17.5L17.5 6.5" />
    </svg>
  )
}
