export interface Item {
  id: number;
  name: string;
  description: string | null;
  is_active: boolean;
  created_at: Date;
  updated_at: Date | null;
}

export interface ItemCreate {
  name: string;
  description?: string;
}
