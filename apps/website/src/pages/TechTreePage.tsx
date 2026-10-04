import { Navigate } from 'react-router-dom'

export default function TechTreePage() {
  // The research graph has one authority and one operational home. Keeping the
  // old static page reachable made two trees disagree about status and unlocks.
  return <Navigate to="/queen" replace />
}
