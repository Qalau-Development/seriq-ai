import { AuthForm } from "@/components/account/AuthForm";

// RegisterPage — регистрация по логину и паролю с предупреждением о пароле
export default function RegisterPage() {
  return <AuthForm mode="register" />;
}
