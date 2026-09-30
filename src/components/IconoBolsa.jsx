// Ícono de bolsa (estilo "Bag" de Tibia) a línea, para que combine con
// el lápiz de editar en vez de un emoji a color.
export default function IconoBolsa({ size = 22 }) {
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
      <path d="M7 9.5C7 7.5 9 6 12 6C15 6 17 7.5 17 9.5L17.6 12.5C18.1 16.5 15.8 19.5 12 19.5C8.2 19.5 5.9 16.5 6.4 12.5Z" />
      <path d="M8 9.5C10.5 11 13.5 11 16 9.5" />
      <path d="M10.5 6L9.3 3" />
      <path d="M13.5 6L14.7 3" />
    </svg>
  )
}
