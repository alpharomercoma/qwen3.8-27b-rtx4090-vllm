import { ChatApp } from "@/components/chat-app";
import { Login } from "@/components/login";
import { isUnlocked } from "@/lib/session";

export default async function Page() {
  return (await isUnlocked()) ? <ChatApp /> : <Login />;
}
