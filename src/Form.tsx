import React, { useState } from 'react';

interface FormProps extends Omit<React.FormHTMLAttributes<HTMLFormElement>, 'action'> {
  action?: (data: FormData) => Promise<any> | any;
  onSubmit?: (event: React.FormEvent<HTMLFormElement>) => void;
}

export function Form({ action, onSubmit, children, ...props }: FormProps) {
  const [isSubmitting, setIsSubmitting] = useState(false);

  const handleSubmit = async (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();

    if (onSubmit) {
      onSubmit(event);
    }

    if (action && !isSubmitting) {
      setIsSubmitting(true);
      try {
        const formData = new FormData(event.currentTarget);
        await action(formData);
      } catch (error) {
        console.error('Form action error:', error);
      } finally {
        setIsSubmitting(false);
      }
    }
  };

  return (
    <form {...props} onSubmit={handleSubmit}>
      {children}
    </form>
  );
}
